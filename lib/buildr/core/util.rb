# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

module Buildr #:nodoc:

  module Util
    extend self

    # Runs Ruby with these command line arguments.  The last argument may be a hash,
    # supporting the following keys:
    #   :command  -- Runs the specified script (e.g., :command=>'gem')
    #   :sudo     -- Run as sudo on operating systems that require it.
    #   :verbose  -- Override Rake's verbose flag.
    def ruby(*args)
      options = Hash === args.last ? args.pop : {}
      cmd = []
      ruby_bin = File.expand_path(RbConfig::CONFIG['ruby_install_name'], RbConfig::CONFIG['bindir'])
      if options.delete(:sudo) && !(Process.uid == File.stat(ruby_bin).uid)
        cmd << 'sudo' << '-u' << "##{File.stat(ruby_bin).uid}"
      end
      cmd << ruby_bin
      cmd << '-S' << options.delete(:command) if options[:command]
      cmd.concat args.flatten
      cmd.push options
      sh *cmd do |ok, status|
        ok or fail "Command ruby failed with status (#{status ? status.exitstatus : 'unknown'}): [#{cmd.join(" ")}]"
      end
    end

    # Return the timestamp of file, without having to create a file task
    def timestamp(file)
      if File.exist?(file)
        File.mtime(file)
      else
        Rake::EARLY
      end
    end

    def uuid
      return SecureRandom.uuid if SecureRandom.respond_to?(:uuid)
      ary = SecureRandom.random_bytes(16).unpack("NnnnnN")
      ary[2] = (ary[2] & 0x0fff) | 0x4000
      ary[3] = (ary[3] & 0x3fff) | 0x8000
      "%08x-%04x-%04x-%04x-%04x%08x" % ary
    end

    # Return the path to the first argument, starting from the path provided by the
    # second argument.
    #
    # For example:
    #   relative_path('foo/bar', 'foo')
    #   => 'bar'
    #   relative_path('foo/bar', 'baz')
    #   => '../foo/bar'
    #   relative_path('foo/bar')
    #   => 'foo/bar'
    #   relative_path('/foo/bar', 'baz')
    #   => '/foo/bar'
    def relative_path(to, from = '.')
      to = Pathname.new(to).cleanpath
      return to.to_s if from.nil?
      to_path = Pathname.new(File.expand_path(to.to_s, "/"))
      from_path = Pathname.new(File.expand_path(from.to_s, "/"))
      to_path.relative_path_from(from_path).to_s
    end

    # Generally speaking, it's not a good idea to operate on dot files (files starting with dot).
    # These are considered invisible files (.svn, .hg, .irbrc, etc).  Dir.glob/FileList ignore them
    # on purpose.  There are few cases where we do have to work with them (filter, zip), a better
    # solution is welcome, maybe being more explicit with include.  For now, this will do.
    def recursive_with_dot_files(*dirs)
      FileList[dirs.map { |dir| File.join(dir, '/**/{*,.*}') }].reject { |file| File.basename(file) =~ /^[.]{1,2}$/ }
    end

    # :call-seq:
    #   replace_extension(filename) => filename_with_updated_extension
    #
    # Replace the file extension, e.g.,
    #   replace_extension("foo.zip", "txt") => "foo.txt"
    def replace_extension(filename, new_ext)
      ext = File.extname(filename)
      if filename =~ /\.$/
        filename + new_ext
      elsif ext == ""
        filename + "." + new_ext
      else
        filename[0..-ext.length] + new_ext
      end
    end

    # Most platforms requires tools.jar to be on the classpath, tools.jar contains the
    # Java compiler (OS X and AIX are two exceptions we know about, may be more).
    # Guess where tools.jar is from JAVA_HOME, which hopefully points to the JDK,
    # but maybe the JRE.  Return nil if not found.
    def tools_jar #:nodoc:
      @tools_jar ||= begin
                       home = ENV['JAVA_HOME'] or fail 'Are we forgetting something? JAVA_HOME not set.'
                       %w[lib/tools.jar ../lib/tools.jar].map { |path| File.expand_path(path, home) }.
                         find { |path| File.exist?(path) }
                     end
    end
  end # Util
end


class Object #:nodoc:
  unless defined? instance_exec # 1.9
    module InstanceExecMethods #:nodoc:
    end
    include InstanceExecMethods

    # Evaluate the block with the given arguments within the context of
    # this object, so self is set to the method receiver.
    #
    # From Mauricio's http://eigenclass.org/hiki/bounded+space+instance_exec
    def instance_exec(*args, &block)
      begin
        old_critical, Thread.critical = Thread.critical, true
        n = 0
        n += 1 while respond_to?(method_name = "__instance_exec#{n}")
        InstanceExecMethods.module_eval { define_method(method_name, &block) }
      ensure
        Thread.critical = old_critical
      end

      begin
        send(method_name, *args)
      ensure
        InstanceExecMethods.module_eval { remove_method(method_name) } rescue nil
      end
    end
  end
end

module Kernel #:nodoc:
  unless defined? tap # 1.9
    def tap
      yield self if block_given?
      self
    end
  end
end

class Symbol #:nodoc:
  unless defined? to_proc # 1.9
    # Borrowed from Ruby 1.9.
    def to_proc
      Proc.new{|*args| args.shift.__send__(self, *args)}
    end
  end
end

unless defined? BasicObject # 1.9
  class BasicObject #:nodoc:
    (instance_methods - %w[__send__ __id__ == send send! respond_to? equal? object_id]).
      each do |method|
        undef_method method
      end

    def self.ancestors
      [Kernel]
    end
  end
end


class OpenObject < Hash

  def initialize(source=nil, &block)
    super &block
    update source if source
  end

  def method_missing(symbol, *args)
    if symbol.to_s =~ /=$/
      self[symbol.to_s[0..-2].to_sym] = args.first
    else
      self[symbol]
    end
  end
end


class Hash

  # :call-seq:
  #   only(keys*) => hash
  #
  # Returns a new hash with only the specified keys.
  #
  # For example:
  #   { :a=>1, :b=>2, :c=>3, :d=>4 }.only(:a, :c)
  #   => { :a=>1, :c=>3 }
  def only(*keys)
    keys.inject({}) { |hash, key| has_key?(key) ? hash.merge(key=>self[key]) : hash }
  end


  # :call-seq:
  #   except(keys*) => hash
  #
  # Returns a new hash without the specified keys.
  #
  # For example:
  #   { :a=>1, :b=>2, :c=>3, :d=>4 }.except(:a, :c)
  #   => { :b=>2, :d=>4 }
  def except(*keys)
    (self.keys - keys).inject({}) { |hash, key| hash.merge(key=>self[key]) }
  end
end

  module FileUtils
    # code "borrowed" directly from Rake
    def sh(*cmd, &block)
      options = (Hash === cmd.last) ? cmd.pop : {}
      unless block_given?
        show_command = cmd.join(" ")
        show_command = show_command[0,42] + "..."

        block = lambda { |ok, status|
          ok or fail "Command failed with status (#{status.exitstatus}): [#{show_command}]"
        }
      end
      if RakeFileUtils.verbose_flag == Rake::FileUtilsExt::DEFAULT
        options[:verbose] = false
      else
        options[:verbose] ||= RakeFileUtils.verbose_flag
      end
      options[:noop]    ||= RakeFileUtils.nowrite_flag
      rake_check_options options, :noop, :verbose
      rake_output_message cmd.join(" ") if options[:verbose]
      unless options[:noop]
        args = if cmd.size > 1 then cmd[1..cmd.size] else [] end
        res = system("cd '#{Dir.pwd}' && " + cmd.first + ' ' + args.map { |a| "'#{a}'" }.join(' '))
        block.call(res, $?)
      end
    end
  end

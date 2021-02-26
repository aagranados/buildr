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

$LOADED_FEATURES << 'jruby' unless RUBY_PLATFORM =~ /java/ # Pretend to have JRuby, keeps Nailgun happy.
require 'buildr/jetty'
require 'buildr/jetty6'
require 'buildr/nailgun'
repositories.remote << 'https://repo1.maven.org/maven2'

define 'buildr' do
  compile.using :source=>'1.7', :target=>'1.7', :debug=>false

  define 'java' do
    compile.using(:javac).from(FileList['lib/buildr/java/**/*.java']).into('lib/buildr/java')
  end

  desc 'Buildr extra packages'
  define 'extra', :version=>'1.0' do
    compile.using(:javac).from(FileList['addon/buildr/**/*.java']).into('addon/buildr').with(Buildr::Jetty::REQUIRES, Buildr::Jetty6::REQUIRES, Buildr::Nailgun::ARTIFACT_SPEC)
    # Legals included in source code and show in RDoc.
    legal = 'LICENSE', 'NOTICE'
    package(:gem).include(legal).path('lib').include('addon/buildr')
    package(:gem).spec do |spec|
      spec.author             = 'Apache Buildr'
      spec.email              = 'users@buildr.apache.org'
      spec.homepage           = "http://buildr.apache.org"
      spec.extra_rdoc_files   = legal
      spec.rdoc_options << '--webcvs' << 'https://github.com/apache/buildr'
      spec.add_dependency 'buildr', '~> 1.3'
    end

    install do
      addon package(:gem)
    end

    upload do
    end
  end
end

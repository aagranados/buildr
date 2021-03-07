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


require File.expand_path(File.join(File.dirname(__FILE__), '..', 'spec_helpers'))

describe OpenObject do
  before do
    @obj = OpenObject.new({:a => 1, :b => 2, :c => 3})
  end

  it "should be kind of Hash" do
    Hash.should === @obj
  end

  it "should accept block that supplies default value" do
    obj = OpenObject.new { |hash, key| hash[key] = "New #{key}" }
    obj[:foo].should == "New foo"
    obj.keys.should == [:foo]
  end

  it "should combine initial values from hash argument and from block" do
    obj = OpenObject.new(:a => 6, :b => 2) { |h, k| h[k] = k.to_s * 2 }
    obj[:a].should == 6
    obj[:c].should == 'cc'
  end

  it "should allow reading a value by calling its name method" do
    @obj.b.should == 2
  end

  it "should allow setting a value by calling its name= method" do
    lambda { @obj.f = 32 }.should change { @obj.f }.to(32)
  end

  it "should allow changing a value by calling its name= method" do
    lambda { @obj.c = 17 }.should change { @obj.c }.to(17)
  end
end

describe File do
  # Quite a few of the other specs depend on File#utime working correctly.
  # These specs validate that utime is working as expected.
  describe "#utime" do
    it "should update mtime of directories" do
      mkpath 'tmp'
      begin
        creation_time = File.mtime('tmp')

        sleep 1
        File.utime(nil, nil, 'tmp')

        File.mtime('tmp').should > creation_time
      ensure
        Dir.rmdir 'tmp'
      end
    end

    it "should update mtime of files" do
      FileUtils.touch('tmp')
      begin
        creation_time = File.mtime('tmp')

        sleep 1
        File.utime(nil, nil, 'tmp')

        File.mtime('tmp').should > creation_time
      ensure
        File.delete 'tmp'
      end
    end

    it "should be able to set mtime in the past" do
      FileUtils.touch('tmp')
      begin
        time = Time.at((Time.now - 10).to_i)
        File.utime(time, time, 'tmp')

        File.mtime('tmp').should == time
      ensure
        File.delete 'tmp'
      end
    end

    it "should be able to set mtime in the future" do
      FileUtils.touch('tmp')
      begin
        time = Time.at((Time.now + 10).to_i)
        File.utime(time, time, 'tmp')

        File.mtime('tmp').should == time
      ensure
        File.delete 'tmp'
      end
    end
  end
end

describe 'Buildr::Util.tools_jar' do
  before do
    @old_home = ENV['JAVA_HOME']
  end

  describe 'when JAVA_HOME points to a JDK' do
    before do
      Buildr::Util.instance_eval { @tools_jar = nil }
      write 'jdk/lib/tools.jar'
      ENV['JAVA_HOME'] = File.expand_path('jdk')
    end

    it 'should return the path to tools.jar' do
      Buildr::Util.tools_jar.should point_to_path('jdk/lib/tools.jar')
    end
  end

  describe 'when JAVA_HOME points to a JRE inside a JDK' do
    before do
      Buildr::Util.instance_eval { @tools_jar = nil }
      write 'jdk/lib/tools.jar'
      ENV['JAVA_HOME'] = File.expand_path('jdk/jre')
    end

    it 'should return the path to tools.jar' do
      Buildr::Util.tools_jar.should point_to_path('jdk/lib/tools.jar')
    end
  end

  describe 'when there is no tools.jar' do
    before do
      Buildr::Util.instance_eval { @tools_jar = nil }
      ENV['JAVA_HOME'] = File.expand_path('jdk')
    end

    it 'should return nil' do
      Buildr::Util.tools_jar.should be_nil
    end
  end

  after do
    ENV['JAVA_HOME'] = @old_home
  end
end

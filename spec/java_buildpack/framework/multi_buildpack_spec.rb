# Cloud Foundry Java Buildpack
# Copyright 2013-2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'spec_helper'
require 'component_helper'
require 'java_buildpack/framework/multi_buildpack'

fdescribe JavaBuildpack::Framework::MultiBuildpack do
  include_context 'component_helper'

  previous_arg_value = ARGV[2]

  before do
    allow(Pathname).to receive(:glob).with('/tmp/*/deps').and_return([Pathname.new(app_dir)])
  end

  it 'does not detect without deps' do
    expect(component.detect).to be_nil
  end

  it 'detects when deps with config.yml exist',
     app_fixture: 'framework_multi_buildpack_deps' do

    expect(component.detect).to eq('multi-buildpack=test-buildpack-0,test-buildpack-2')
  end

  it 'adds bin/ directory to $PATH during compile if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(environment_variables).to include('PATH=$PATH:$PWD/0/bin')
  end

  it 'adds bin/ directory to $PATH during release if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(environment_variables).to include('PATH=$PATH:$PWD/0/bin')
  end

  it 'adds lib/ directory to $LD_LIBRARY_PATH during compile if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.compile

    expect(environment_variables).to include('LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/0/lib')
  end

  it 'adds lib/ directory to $LD_LIBRARY_PATH during release if it exists',
     app_fixture: 'framework_multi_buildpack_deps' do

    component.release

    expect(environment_variables).to include('LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$PWD/0/lib')
  end

end

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

require 'fileutils'
require 'pathname'
require 'java_buildpack/component/base_component'
require 'java_buildpack/framework'
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/qualify_path'
require 'yaml'

module JavaBuildpack
  module Framework

    # Encapsulates the functionality for multi buildpack support.
    class MultiBuildpack < JavaBuildpack::Component::BaseComponent
      include JavaBuildpack::Util

      # (see JavaBuildpack::Component::BaseComponent#initialize)
      def initialize(context)
        super(context)

        @logger = JavaBuildpack::Logging::LoggerFactory.instance.get_logger MultiBuildpack
        @logger.debug { "Dependencies Directory: #{ARGV[3]}" }
      end

      # (see JavaBuildpack::Component::BaseComponent#detect)
      def detect
        !dep_directories.empty? ? "multi-buildpack=#{names(dep_directories).join(',')}" : nil
      end

      # (see JavaBuildpack::Component::BaseComponent#compile)
      def compile
        puts "#{'----->'.red.bold} #{'Multiple Buildpacks'.blue.bold} detected"

        dep_directories.each do |dep_directory|
          config = config(config_file(dep_directory))
          name   = name(config)

          log_configuration config
          log_dep_contents dep_directory

          contributions = []
          contributions << add_bin(dep_directory)
          contributions << add_lib(dep_directory)
          contributions << add_additional_libraries(config)
          contributions << add_environment_variables(config)
          contributions << add_extension_directories(config)
          # TODO contributions << add_java_opts(config)
          contributions << add_security_providers(config)

          puts "       #{name}#{contributions_message(contributions)}"
        end
      end

      # (see JavaBuildpack::Component::BaseComponent#release)
      def release
        dep_directories.each do |dep_directory|
          config = config(config_file(dep_directory))

          add_bin(dep_directory)
          add_lib(dep_directory)
          add_additional_libraries(config)
          add_environment_variables(config)
          add_extension_directories(config)
          # TODO add_java_opts(config)
          add_security_providers(config)
        end
      end

      private

      def add_additional_libraries(config)
        additional_libraries = config['config']['additional_libraries']
        return unless additional_libraries

        additional_libraries.each do |additional_library|
          @droplet.additional_libraries << Pathname.new(additional_library)
        end

        'Additional Libraries'
      end

      def add_bin(dep_directory)
        bin_directory = dep_directory + 'bin'
        return unless bin_directory.exist?

        @droplet.environment_variables
                .add_environment_variable('PATH', "$PATH:#{qualify_path(bin_directory, @droplet.root)}")

        '$PATH'
      end

      def add_environment_variables(config)
        environment_variables = config['config']['environment_variables']
        return unless environment_variables

        environment_variables.each do |key, value|
          path = Pathname.new(value);

          if path.exist?
            @droplet.environment_variables.add_environment_variable key, path
          else
            @droplet.environment_variables.add_environment_variable key, value
          end

        end

        'Environment Variables'
      end

      def add_extension_directories(config)
        extension_directories = config['config']['extension_directories']
        return unless extension_directories

        extension_directories.each do |extension_directory|
          @droplet.extension_directories << Pathname.new(extension_directory)
        end

        'Extension Directories'
      end

      def add_lib(dep_directory)
        lib_directory = dep_directory + 'lib'
        return unless lib_directory.exist?

        @droplet.environment_variables
                .add_environment_variable('LD_LIBRARY_PATH',
                                          "$LD_LIBRARY_PATH:#{qualify_path(lib_directory, @droplet.root)}")

        '$LD_LIBRARY_PATH'
      end

      def add_security_providers(config)
        security_providers = config['config']['security_providers']
        return unless security_providers

        security_providers.each do |security_provider|
          @droplet.security_providers << security_provider
        end

        'Security Providers'
      end

      def config(config_file)
        YAML.load_file(config_file)
      end

      def config_file(dep_directory)
        dep_directory + 'config.yml'
      end

      def contributions_message(contributions)
        return if contributions.compact.empty?
        " contributed to: #{contributions.flatten.compact.sort.join(', ')}"
      end

      def dep_directories
        Pathname.glob('/tmp/*/deps')
                .first
                .children
                .select { |dep_directory| config_file(dep_directory).exist? }
                .sort_by(&:basename)
      end

      def log_configuration(config)
        @logger.debug { "Configuration: #{config}" }
      end

      def log_dep_contents(dep_directory)
        @logger.debug do
          paths = []
          dep_directory.find { |f| paths << f.relative_path_from(dep_directory).to_s }

          "Application Contents (#{dep_directory}): #{paths}"
        end
      end

      def name(config)
        config['name']
      end

      def names(dep_directories)
        dep_directories.map { |dep_directory| name(config(config_file(dep_directory))) }
      end

    end

  end
end

require 'cocoapods-bb-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-bb-bin/helpers/framework_builder'
require 'cocoapods-bb-bin/helpers/library_builder'
require 'cocoapods-bb-bin/helpers/sources_helper'
require 'cocoapods-bb-bin/command/bin/repo/push'

module CBin
  class Push
    class Helper
      include CBin::SourcesHelper

      def initialize()
      end

      # 上传二进制 podspec
      def push_binary_repo(binary_podsepc_json)
        argvs = [
            "#{binary_source.name}",  # repo
            "#{binary_podsepc_json}", # spec
            "--binary",
            "--sources=#{binary_source},https:\/\/cdn.cocoapods.org",
            "--skip-import-validation",
            "--use-libraries",
            "--allow-warnings",
            "--verbose",
            "--code-dependencies",
            '--no-cocoapods-validator', #不采用cocoapods验证
        ]
        if @verbose
          argvs += ['--verbose']
        end
        Pod::UI.message "上传二进制 argvs: #{argvs}"
        push = Pod::Command::Bin::Repo::Push.new(CLAide::ARGV.new(argvs))
        push.validate!
        push.run
      end

      # 上传源码podspec
      def push_source_repo(source_podsepc_json)
        argvs = [
          "#{code_source.name}",  # repo
          "#{source_podsepc_json}", # spec
          "--sources=#{code_source},https:\/\/cdn.cocoapods.org",
          "--skip-import-validation",
          "--use-libraries",
          "--allow-warnings",
          "--verbose",
          "--code-dependencies",
          '--no-cocoapods-validator', #不采用cocoapods验证
        ]
        if @verbose
          argvs += ['--verbose']
        end
        Pod::UI.message "上传源码 argvs: #{argvs}"
        push = Pod::Command::Bin::Repo::Push.new(CLAide::ARGV.new(argvs))
        push.validate!
        push.run
      end

    end
  end
end
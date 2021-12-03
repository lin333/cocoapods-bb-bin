require 'cocoapods-bb-bin/config/config'
require 'cocoapods-bb-bin/native/podfile'
require 'cocoapods/command/lib/lint'
require 'cocoapods'

module Pod
  class Command
    class Bin < Command
      class Lib < Bin
        class Lint < Lib
          self.summary = 'Validates a Pod'

          self.description = <<-DESC
            Validates the Pod using the files in the working directory.
          DESC

          self.arguments = [
            CLAide::Argument.new('NAME.podspec', false),
          ]

          # lib lint 不会下载 source，所以不能进行二进制 lint
          # 要 lint 二进制版本，需要进行 spec lint，此 lint 会去下载 source
          def self.options
            [
              ['--code-dependencies', '使用源码依赖进行 lint'],
              ['--loose-options', '添加宽松的 options, 包括 --use-libraries (可能会造成 entry point (start) undefined)'],
              ['--allow-prerelease', '允许使用 prerelease 的版本 lint'],
              ['--bb-env', 'bb Company environment(Internal use),support oc、swift project']
            ].concat(Pod::Command::Lib::Lint.options).concat(super).uniq
          end

          def initialize(argv)
            @loose_options = argv.flag?('loose-options')
            @code_dependencies = argv.flag?('code-dependencies', true)
            @sources = argv.option('sources') || []
            @allow_prerelease = argv.flag?('allow-prerelease')
            @bb_env = argv.flag?('bb-env', false)
            @podspec = argv.shift_argument
            super
            @additional_args = argv.remainder!
          end

          def run
            # @bb_env = false
            if @bb_env
              Podfile.execute_with_bin_plugin do
                Podfile.execute_with_use_binaries(!@code_dependencies) do
                  build_bb_lint
                end
              end
            else
              Podfile.execute_with_bin_plugin do
                Podfile.execute_with_allow_prerelease(@allow_prerelease) do
                  Podfile.execute_with_use_binaries(!@code_dependencies) do
                    argvs = [
                      @podspec || code_spec_files.first,
                      "--sources=#{sources_option(@code_dependencies, @sources)}",
                      *@additional_args
                    ]

                    if @loose_options
                      argvs << '--allow-warnings'
                      if code_spec&.all_dependencies&.any?
                        argvs << '--use-libraries'
                      end
                    end

                    lint = Pod::Command::Lib::Lint.new(CLAide::ARGV.new(argvs))
                    lint.validate!
                    lint.run
                  end
                end
              end
            end
          end

          private

          def build_bb_lint
            UI.section("\npod bin lib lint\n".yellow) do
              begin
                if @podspec && !@podspec.empty?
                  argvs = [
                    @podspec, # 业务方传入podspec,对于业务方没有传入podspec，内部由podspecs_to_lint进行遍历
                    # '--verbose',
                    '--allow-warnings',
                    '--use-static-frameworks',
                    '--no-clean',
                    '--skip-import-validation',
                    '--use-modular-headers',
                    "--sources=#{sources_option(@code_dependencies, @sources)}",
                    '--swift-version=5.0',
                    *@additional_args
                  ]
                  argvs += ['--verbose'] if @verbose
                else
                  argvs = [
                    # '--verbose',
                    '--allow-warnings',
                    '--use-static-frameworks',
                    '--no-clean',
                    '--skip-import-validation',
                    '--use-modular-headers',
                    "--sources=#{sources_option(@code_dependencies, @sources)}",
                    '--swift-version=5.0',
                    *@additional_args
                  ]
                  argvs += ['--verbose'] if @verbose
                end
                
                puts "pod bin lib lint argvs:#{argvs}"
                lint = Pod::Command::Lib::Lint.new(CLAide::ARGV.new(argvs))
                lint.validate!
                lint.run
              rescue Object => exception
                UI.puts "fail....."
                UI.puts exception
              end
            end
          end

        end
      end
    end
  end
end

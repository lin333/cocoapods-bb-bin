require 'cocoapods-bb-bin/config/config'
require 'cocoapods-bb-bin/native/podfile'
require 'cocoapods-bb-bin/native/push'

module Pod
  class Command
    class Bin < Command
      class Repo < Bin
        class Push < Repo
          self.summary = '发布组件.'
          self.description = <<-DESC
            发布二进制组件 / 源码组件
          DESC

          self.arguments = [
            CLAide::Argument.new('NAME.podspec', false)
          ]

          def self.options
            [
              ['--binary', '发布组件的二进制版本'],
              ['--template-podspec=A.binary-template.podspec', '生成拥有 subspec 的二进制 spec 需要的模版 podspec, 插件会更改 version 和 source'],
              ['--reserve-created-spec', '保留生成的二进制 spec 文件'],
              ['--code-dependencies', '使用源码依赖进行 lint'],
              ['--loose-options', '添加宽松的 options, 包括 --use-libraries (可能会造成 entry point (start) undefined)'],
              ['--allow-prerelease', '允许使用 prerelease 的版本 lint'],
              ['--use-static-frameworks', 'Lint uses static frameworks during installation,support modulemap'],
              ['--bb-env', 'bb Company environment(Internal use),support oc、swift project']
            ].concat(Pod::Command::Repo::Push.options).concat(super).uniq
          end

          def initialize(argv)
            @podspec = argv.shift_argument
            @binary = argv.flag?('binary')
            @loose_options = argv.flag?('loose-options')
            @code_dependencies = argv.flag?('code-dependencies', true)
            @sources = argv.option('sources') || []
            @reserve_created_spec = argv.flag?('reserve-created-spec')
            @template_podspec = argv.option('template-podspec')
            @allow_prerelease = argv.flag?('allow-prerelease')
            @use_static_frameworks = argv.flag?('use-static-frameworks', true)
            @bb_env = argv.flag?('bb-env', false)
            super
            @additional_args = argv.remainder!
            @message = argv.option('commit-message')
            @commit_message = argv.flag?('commit-message', false)
            @use_json = argv.flag?('use-json')
            @verbose = argv.flag?('verbose', false)
            @local_only = argv.flag?('local-only')
          end

          def run
            # @bb_env = false
            if @bb_env
              Podfile.execute_with_bin_plugin do
                Podfile.execute_with_use_binaries(!@code_dependencies) do
                  build_bb_push
                end
              end
            else
              Podfile.execute_with_bin_plugin do
                Podfile.execute_with_allow_prerelease(@allow_prerelease) do
                  Podfile.execute_with_use_binaries(!@code_dependencies) do
                    argvs = [
                      repo,
                      "--sources=#{sources_option(@code_dependencies, @sources)}",
                      *@additional_args
                    ]
  
                    argvs << spec_file if spec_file
  
                    if @loose_options
                      argvs += ['--allow-warnings', '--use-json']
                      if code_spec&.all_dependencies&.any?
                        argvs << '--use-libraries'
                      end
                    end
  
                    push = Pod::Command::Repo::Push.new(CLAide::ARGV.new(argvs))
                    push.validate!
                    push.run
                  end
                end
              end
            end
          ensure
            clear_binary_spec_file_if_needed unless @reserve_created_spec
          end

          private
          def build_bb_push
            UI.section("\npod bin repo push\n".yellow) do
              begin
                unless @podspec && !@podspec.empty? # 遍历当前目录下podspec文件
                  podspecs = Pathname.glob(Pathname.pwd + '*.podspec{.json,}')
                  if podspecs.count.zero?
                    raise Informative, 'Unable to find a podspec in the working ' \
                      'directory'
                  end
                  @podspec = podspecs.first
                end
                argvs = [
                  repo, # 内部判断区源码还是二进制
                  @podspec,
                  "--sources=#{sources_option(@code_dependencies, @sources)}",
                  # '--verbose'
                  '--allow-warnings',
                  '--use-static-frameworks',
                  '--skip-import-validation',
                  '--use-modular-headers',
                  '--swift-version=5.0',
                  *@additional_args
                ]
                argvs += ['--verbose'] if @verbose
                argvs += ['--commit-message'] if @message
                argvs += ['--use-json'] if @use_json
                argvs += ['--local-only'] if @local_only

                # UI.puts "pod repo push argvs:#{argvs}"
                push = Pod::Command::Repo::Push.new(CLAide::ARGV.new(argvs))
                push.validate!
                push.run
              rescue Object => exception
                UI.puts exception
              end
            end
          end

          def template_spec_file
            @template_spec_file ||= begin
              if @template_podspec
                find_spec_file(@template_podspec)
              else
                binary_template_spec_file
              end
            end
          end

          def spec_file
            @spec_file ||= begin
              if @podspec
                find_spec_file(@podspec)
              else
                if code_spec_files.empty?
                  raise Informative, '当前目录下没有找到可用源码 podspec.'
                end

                spec_file = if @binary
                              code_spec = Pod::Specification.from_file(code_spec_files.first)
                              if template_spec_file
                                template_spec = Pod::Specification.from_file(template_spec_file)
                              end
                              create_binary_spec_file(code_spec, template_spec)
                            else
                              code_spec_files.first
                            end
                spec_file
              end
            end
          end

          def repo
            @binary ? binary_source.name : code_source.name
          end
        end
      end
    end
  end
end

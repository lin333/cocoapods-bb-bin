require 'cocoapods-bb-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'xcodeproj'
require 'cocoapods-bb-bin/helpers/push_spec_helper'
require 'cocoapods-bb-bin/helpers/build_helper'
require 'cocoapods-bb-bin/helpers/spec_source_creator'

module Pod
  class Command
    class Bin < Command
      class Tag < Bin
        self.summary = '推送标签.'

        self.arguments = [
            CLAide::Argument.new('NAME.podspec', false)
        ]
        def self.options
          [
            ['--sources', '私有源地址，多个用分号区分'],
            ['--no-clean', '保留构建中间产物'],
            ['--skip-build-project', '跳过编译工程文件操作(直接推送假标签，操作慎重!!!)'],
            ['--debug', 'debug环境只是验证工程编译是否ok，不进行标签推送操作'],
          ].concat(Pod::Command::Gen.options).concat(super).uniq
        end

        def initialize(argv)
          @help = argv.flag?('help', false )
          if @help
          else
            @env = argv.option('env') || 'dev'
            CBin.config.set_configuration_env(@env)
  
            @podspec = argv.shift_argument || find_podspec
            @sources = argv.option('sources') || []
            @clean = argv.flag?('no-clean', false)
            @skip_build_project = argv.flag?('skip-build-project', false)
            @is_debug = argv.flag?('debug', false)
            @platform = Platform.new(:ios)
          end
          super
        end

        def validate!
            help! "未找到 podspec文件" unless @podspec
            super
          end

        def run
          # 清除之前的缓存
          CBin::Config::Builder.instance.clean
          @spec = Specification.from_file(@podspec)

          if @skip_build_project
            # 跳过工程编译
            is_build_ok = true
            Pod::UI.warn "请注意⚠️正在推送假标签！！！#{@podspec}==>#{@spec.name}(#{@spec.version})"
          elsif
            # step.1 工程编译
            is_build_ok = check_build_workspace
          end
          if is_build_ok && !@is_debug
            # step.2 工程编译ok，进行标签推送
            push_helper = CBin::Push::Helper.new()
            push_helper.push_source_repo(@podspec)
          end
        end

        #Dir.glob 可替代
        def find_podspec
            name = nil
            Pathname.pwd.children.each do |child|
              # puts child
              if File.file?(child)
                if child.extname == '.podspec'
                  name = File.basename(child)
                  unless name.include?("binary-template")
                    return name
                  end
                end
              end
            end
            raise Informative,  "podspec File no exist, please check" unless name
            return name
        end

        # 编译工程目录
        def check_build_workspace
          generate_project
          swift_pods_buildsetting
          return build_root_spec
        end

        private
        def build_root_spec
          builder = CBin::Build::Helper.new(@spec,
                                            @platform,
                                            false,
                                            false,
                                            @sources,
                                            true,
                                            @spec,
                                            CBin::Config::Builder.instance.white_pod_list.include?(@spec.name),
                                            'Release')
          builder.build
          builder.clean_workspace if @clean
          return builder.is_build_finish
        end
        def swift_pods_buildsetting
          # swift_project_link_header
          worksppace_path = File.expand_path("#{CBin::Config::Builder.instance.gen_dir}/#{@spec.name}")
          path = File.join(worksppace_path, "Pods.xcodeproj")
          path = File.join(worksppace_path, "Pods/Pods.xcodeproj") unless File.exist?(path)
          raise Informative,  "#{path} File no exist, please check" unless File.exist?(path)
          project = Xcodeproj::Project.open(path)
          project.build_configurations.each do |x|
            x.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = true #设置生成swift inter
          end
          project.save
        end

        def generate_project
          Podfile.execute_with_bin_plugin do
            Podfile.execute_with_use_binaries(!@code_dependencies) do
                argvs = [
                  "--sources=#{sources_option(@code_dependencies, @sources)}",
                  "--gen-directory=#{CBin::Config::Builder.instance.gen_dir}",
                  '--clean',
                  "--verbose",
                  *@additional_args
                ]
                podfile_path = Pod::Config.instance.podfile_path
                if podfile_path && File.exist?(podfile_path)
                  argvs += ['--use-podfile']
                end

                if CBin::Build::Utils.uses_frameworks? # 组件库重新生成pod工程引入静态库需要使用该选项，否则报cocoapods中verify_no_static_framework_transitive_dependencies验证无法通过 by hm 21/10/18
                  argvs += ['--use-libraries']
                end

                argvs << @podspec if @podspec
                # UI.puts "argvs:#{argvs}"
                gen = Pod::Command::Gen.new(CLAide::ARGV.new(argvs))
                gen.validate!
                gen.run
            end
          end
        end

      end
    end
  end
end

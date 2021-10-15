# copy from https://github.com/humin1102/cocoapods-bb-xcframework

require 'cocoapods/command/gen'
require 'cocoapods/generate'

require 'cocoapods-xcframework/config'
require 'cocoapods-xcframework/util'
require 'cocoapods-xcframework/xbuilder'
require 'cocoapods-xcframework/frameworker'
require 'cocoapods-xcframework/muti_frameworker'

module CBin
    class XCFramework
        class XCBuilder
            include Pod
            include Pod::Config::Mixin
            def initialize(spec,spec_sources)
                @spec = spec
                @spec_sources = spec_sources.split(',') unless spec_sources.nil?
                @name = "#{@spec.name}.podspec"
                @source = nil
                @subspecs = nil
                @configuration = 'Release'
                @use_modular_headers = true
                @force = true
                @use_static_library = true
                @enable_bitcode = false
                
                target_dir = "#{Dir.pwd}/#{@spec.name}-#{@spec.version}"
                UI.puts "build initialize...#{spec} target_dir:#{target_dir}"
                UI.puts "spec_sources:#{spec_sources}"
                UI.puts "spec_sources:#{@spec_sources}"
            end

            def build
                UI.section("Building static xcframework #{@spec}") do
                    config.static_library_enable = @use_static_library # 一定要配置 true，否则调用xcframework生成命令无效
                    frameworker = Frameworker.new(@name, @source, @spec_sources, @subspecs, @configuration, @force, @use_modular_headers, @enable_bitcode)
                    frameworker.run
                    # 拷贝
                    cp_to_source_dir
                end
            end

            private

            def framework_folder_path
                target_dir = "#{Dir.pwd}/#{@spec.name}-#{@spec.version}"
                return target_dir
            end

            def framework_name
                framework_name = "#{@spec.name}.xcframework"
                return framework_name
            end

            def framework_file_path
                target_dir = File.join(framework_folder_path,framework_name)
                return target_dir
            end

            def cp_to_source_dir

                target_dir = File.join(CBin::Config::Builder.instance.zip_dir,framework_name)
                FileUtils.rm_rf(target_dir) if File.exist?(target_dir)

                zip_dir = CBin::Config::Builder.instance.zip_dir
                FileUtils.mkdir_p(zip_dir) unless File.exist?(zip_dir)

                UI.puts "Compressing #{framework_file_path} into #{target_dir}"
                `cp -fa #{framework_file_path} #{target_dir} && rm -rf #{framework_folder_path}` # xcframework文件拷贝 & 删除源文件
            end
        end
    end
end
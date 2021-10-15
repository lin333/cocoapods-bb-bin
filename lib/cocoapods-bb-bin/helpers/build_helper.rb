# copy from https://github.com/CocoaPods/cocoapods-packager

require 'cocoapods-bb-bin/native/podfile'
require 'cocoapods/command/gen'
require 'cocoapods/generate'
require 'cocoapods-bb-bin/helpers/framework_builder'
require 'cocoapods-bb-bin/helpers/xcframework_builder'
require 'cocoapods-bb-bin/helpers/library_builder'
require 'cocoapods-bb-bin/config/config_builder'

module CBin
  class Build
    class Helper
      include Pod
#class var
      @@build_defines = ""
#Debug下还待完成
      def initialize(spec,
                     platform,
                     framework_output,
                     xcframework_output,
                     spec_sources,
                     zip,
                     rootSpec,
                     skip_archive = false,
                     build_model="Release")
        @spec = spec
        @platform = platform
        @build_model = build_model
        @rootSpec = rootSpec
        @isRootSpec = rootSpec.name == spec.name
        @skip_archive = skip_archive
        @framework_output = framework_output
        @xcframework_output = xcframework_output
        @spec_sources = spec_sources
        @zip = zip

        @framework_path

        UI.puts "build initialize...#{spec}"
      end

      # build framework
      def build
        UI.section("Building static framework #{@spec}") do
          # 生成静态库支持xcframework
          has_xcframework = is_build_xcframework
          if has_xcframework == true
            UI.puts "build static xcframework"
            build_static_xcframework
            unless @skip_archive
              zip_static_xcframework
            end
          else
            UI.puts "build static framework"
            build_static_framework
            unless @skip_archive
              unless  CBin::Build::Utils.is_framework(@spec)
                build_static_library
                zip_static_library
              else
                zip_static_framework
              end
            end
          end
        end

      end

      # 是否编译xcframework库
      def is_build_xcframework
        if @xcframework_output == true
          return true
        end
        return false
      end
      # build xcframework
      def build_static_xcframework
        source_dir = Dir.pwd
        UI.puts "xcframework source_dir=#{source_dir}"
        builder = CBin::XCFramework::XCBuilder.new(@spec, @spec_sources)
        builder.build
      end

      # build framework
      def build_static_framework
        source_dir = Dir.pwd
        file_accessor = Sandbox::FileAccessor.new(Pathname.new('.').expand_path, @spec.consumer(@platform))
        Dir.chdir(workspace_directory) do
          builder = CBin::Framework::Builder.new(@spec, file_accessor, @platform, source_dir, @isRootSpec, @build_model )
          @@build_defines = builder.build if @isRootSpec
          begin
            @framework_path = builder.lipo_build(@@build_defines) unless @skip_archive
          rescue
            @skip_archive = true
          end
        end
      end

      def build_static_library
        source_dir = zip_dir
        file_accessor = Sandbox::FileAccessor.new(Pathname.new('.').expand_path, @spec.consumer(@platform))
        Dir.chdir(workspace_directory) do
          builder = CBin::Library::Builder.new(@spec, file_accessor, @platform, source_dir,@framework_path)
          builder.build
        end
      end

      def zip_static_xcframework
        Dir.chdir(zip_dir) do
          output_name =  File.join(zip_dir, xcframework_name_zip)
          unless File.exist?(xcframework_name)
            UI.puts "没有需要压缩的 xcframework 文件：#{xcframework_name}"
            return
          end

          UI.puts "Compressing #{xcframework_name} into #{output_name}"
          `zip --symlinks -r #{output_name} #{xcframework_name} && rm -rf #{xcframework_name}` # xcframework进行zip压缩 & 删除源文件
        end
      end

      def zip_static_framework
        Dir.chdir(File.join(workspace_directory,@framework_path.root_path)) do
          output_name =  File.join(zip_dir, framework_name_zip)
          unless File.exist?(framework_name)
            UI.puts "没有需要压缩的 framework 文件：#{framework_name}"
            return
          end

          UI.puts "Compressing #{framework_name} into #{output_name}"
          `zip --symlinks -r #{output_name} #{framework_name}`
        end
      end

      def zip_static_library
        Dir.chdir(zip_dir) do
          output_library = "#{library_name}.zip"
          unless File.exist?(library_name)
            raise Informative, "没有需要压缩的 library 文件：#{library_name}"
          end

          UI.puts "Compressing #{library_name} into #{output_library}"

          `zip --symlinks -r #{output_library} #{library_name}`
        end

      end


      def clean_workspace
        UI.puts 'Cleaning workspace'

        FileUtils.rm_rf(gen_name)
        Dir.chdir(zip_dir) do
          # framework
          FileUtils.rm_rf(framework_name) if @zip
          FileUtils.rm_rf(library_name)
          FileUtils.rm_rf(framework_name) unless @framework_output
          FileUtils.rm_rf("#{framework_name}.zip") unless @framework_output
          # xcframework
          FileUtils.rm_rf(xcframework_name) if @zip
          FileUtils.rm_rf(xcframework_name) unless @framework_output
          FileUtils.rm_rf("#{xcframework_name}.zip") unless @framework_output
        end
      end

      def xcframework_name
        CBin::Config::Builder.instance.xcframework_name(@spec)
      end

      def xcframework_name_zip
        CBin::Config::Builder.instance.xcframework_name_version(@spec) + ".zip"
      end

      def framework_name
        CBin::Config::Builder.instance.framework_name(@spec)
      end

      def framework_name_zip
        CBin::Config::Builder.instance.framework_name_version(@spec) + ".zip"
      end

      def library_name
        CBin::Config::Builder.instance.library_name(@spec)
      end

      def workspace_directory
        File.expand_path("#{gen_name}/#{@rootSpec.name}")
      end

      def zip_dir
        CBin::Config::Builder.instance.zip_dir
      end

      def gen_name
        CBin::Config::Builder.instance.gen_dir
      end


      def spec_file
        @spec_file ||= begin
                         if @podspec
                           find_spec_file(@podspec)
                         else
                           if code_spec_files.empty?
                             raise Informative, '当前目录下没有找到可用源码 podspec.'
                           end

                           spec_file = code_spec_files.first
                           spec_file
                         end
                       end
      end

    end
  end
end

require 'yaml'
require 'cocoapods-bb-bin/config/config'

module CBin
  class Build

    class Utils

      def Utils.is_framework(spec)
        if Utils.uses_frameworks?
          return true
        end
        if Utils.is_generate_frameworks(spec)
          return true
        end

        return Utils.is_swift_module(spec)
      end

      def Utils.is_swift_module(spec)

        is_framework = false
        dir = File.join(CBin::Config::Builder.instance.gen_dir, CBin::Config::Builder.instance.target_name)
        #auto 走这里
        if File.exist?(dir)
          Dir.chdir(dir) do
            public_headers = Array.new
            spec_header_dir = "./Headers/Public/#{spec.name}"

            unless File.exist?(spec_header_dir)
              spec_header_dir = "./Pods/Headers/Public/#{spec.name}"
            end
            return false unless File.exist?(spec_header_dir)

            is_framework = File.exist?(File.join(spec_header_dir, "#{spec.name}-umbrella.h"))
          end
        end

        if $ARGV[1] == "local"
          is_framework = File.exist?(File.join(CBin::Config::Builder.instance.xcode_build_dir, "#{spec.name}.framework"))
          unless is_framework
            is_framework = File.exist?(File.join(CBin::Config::Builder.instance.xcode_BuildProductsPath_dir, "#{spec.name}","Swift Compatibility Header"))
          end
        end

        is_framework
      end

      def Utils.uses_frameworks?
        uses_frameworks = false
        podfile_path = Pod::Config.instance.podfile_path
        unless podfile_path
          return true
        end
        Pod::Config.instance.podfile.target_definitions.each do |key,value|
          if key != "Pods"
            uses_frameworks = value.uses_frameworks?
            if uses_frameworks
              break ;
            end
          end
        end

        return uses_frameworks
      end

      def Utils.is_generate_frameworks(spec)
        # framework
        zip_file = CBin::Config::Builder.instance.framework_zip_file(spec) + ".zip"
        res = File.exist?(zip_file)
        Pod::UI::puts "zip_file = #{zip_file}"
        unless res
          # xcframework
          zip_file = CBin::Config::Builder.instance.xcframework_zip_file(spec) + ".zip"
          res = File.exist?(zip_file)
          Pod::UI::puts "zip_file = #{zip_file}"
        end
        if res
          is_framework = true
        end
        return is_framework
      end

    end

  end
end

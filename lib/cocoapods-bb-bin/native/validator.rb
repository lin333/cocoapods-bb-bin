

module Pod
  class Validator
    # @return [Boolean] 使用cocoapods进行验证，二进制库推送默认不采用cocoapods(1.11.2)验证
    #
    # attr_accessor :use_cocoapods_validator
    def initialize(spec_or_path, source_urls, platforms = [], use_cocoapods_validator = false)
      @use_cocoapods_validator = use_cocoapods_validator
      @use_frameworks = true
      @linter = Specification::Linter.new(spec_or_path)
      @source_urls = if @linter.spec && @linter.spec.dependencies.empty? && @linter.spec.recursive_subspecs.all? { |s| s.dependencies.empty? }
                       []
                     else
                       source_urls.map { |url| config.sources_manager.source_with_name_or_url(url) }.map(&:url)
                     end

      @platforms = platforms.map do |platform|
        result =  case platform.to_s.downcase
                  # Platform doesn't recognize 'macos' as being the same as 'osx' when initializing
                  when 'macos' then Platform.macos
                  else Platform.new(platform, nil)
                  end
        unless valid_platform?(result)
          raise Informative, "Unrecognized platform `#{platform}`. Valid platforms: #{VALID_PLATFORMS.join(', ')}"
        end
        result
      end
      @use_frameworks = true
    end

    # Perform analysis for a given spec (or subspec)
    #
    def perform_extensive_analysis(spec)
      if @use_cocoapods_validator
        return cocoapods_perform_extensive_analysis(spec) 
      end
      return true
    end

    #覆盖
    def check_file_patterns
      if @use_cocoapods_validator
        cocoapods_check_file_patterns
        return
      end
      # 二进制验证部分
      FILE_PATTERNS.each do |attr_name|
        next if %i(source_files resources).include? attr_name
          if respond_to?("_validate_#{attr_name}", true)
            send("_validate_#{attr_name}")
          else
            validate_nonempty_patterns(attr_name, :error)
          end
      end

      _validate_header_mappings_dir
      if consumer.spec.root?
        _validate_license
        _validate_module_map
      end
    end

    def validate_source_url(spec)
      if @use_cocoapods_validator
        cocoapods_validate_source_url(spec)
        return
      end
    end

    # cocoapods(1.11.2) validator源码
    private

    # It checks that every file pattern specified in a spec yields
    # at least one file. It requires the pods to be already present
    # in the current working directory under Pods/spec.name.
    #
    # @return [void]
    #
    def cocoapods_check_file_patterns
      FILE_PATTERNS.each do |attr_name|
        if respond_to?("_validate_#{attr_name}", true)
          send("_validate_#{attr_name}")
        else
          validate_nonempty_patterns(attr_name, :error)
        end
      end

      _validate_header_mappings_dir
      if consumer.spec.root?
        _validate_license
        _validate_module_map
      end
    end

    # Performs validations related to the `source` -> `http` attribute (if exists)
    #
    def cocoapods_validate_source_url(spec)
      return if spec.source.nil? || spec.source[:http].nil?
      url = URI(spec.source[:http])
      return if url.scheme == 'https' || url.scheme == 'file'
      warning('http', "The URL (`#{url}`) doesn't use the encrypted HTTPS protocol. " \
              'It is crucial for Pods to be transferred over a secure protocol to protect your users from man-in-the-middle attacks. '\
              'This will be an error in future releases. Please update the URL to use https.')
    end

    # Perform analysis for a given spec (or subspec)
    #
    def cocoapods_perform_extensive_analysis(spec)
      if spec.non_library_specification?
        error('spec', "Validating a non library spec (`#{spec.name}`) is not supported.")
        return false
      end
      validate_homepage(spec)
      validate_screenshots(spec)
      validate_social_media_url(spec)
      validate_documentation_url(spec)
      validate_source_url(spec)

      platforms = platforms_to_lint(spec)

      valid = platforms.send(fail_fast ? :all? : :each) do |platform|
        UI.message "\n\n#{spec} - Analyzing on #{platform} platform.".green.reversed
        @consumer = spec.consumer(platform)
        setup_validation_environment
        begin
          create_app_project
          download_pod
          check_file_patterns
          install_pod
          validate_swift_version
          add_app_project_import
          validate_vendored_dynamic_frameworks
          build_pod
          test_pod unless skip_tests
        ensure
          tear_down_validation_environment
        end
        validated?
      end
      return false if fail_fast && !valid
      perform_extensive_subspec_analysis(spec) unless @no_subspecs
    rescue => e
      message = e.to_s
      message << "\n" << e.backtrace.join("\n") << "\n" if config.verbose?
      error('unknown', "Encountered an unknown error (#{message}) during validation.")
      false
    end

  end
end

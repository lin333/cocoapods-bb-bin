require 'tempfile'
require 'fileutils'
require 'active_support/core_ext/string/inflections'

module Pod
  class Command
    class Repo < Command
      class Push < Repo

        def initialize(argv)
          @allow_warnings = argv.flag?('allow-warnings')
          @local_only = argv.flag?('local-only')
          @repo = argv.shift_argument
          @source = source_for_repo
          @source_urls = argv.option('sources', config.sources_manager.all.map(&:url).append(Pod::TrunkSource::TRUNK_REPO_URL).uniq.join(',')).split(',')
          @update_sources = argv.flag?('update-sources')
          @podspec = argv.shift_argument
          @use_frameworks = !argv.flag?('use-libraries')
          @use_modular_headers = argv.flag?('use-modular-headers', false)
          @use_static_frameworks = argv.flag?('use-static-frameworks')
          @private = argv.flag?('private', true)
          @message = argv.option('commit-message')
          @commit_message = argv.flag?('commit-message', false)
          @use_json = argv.flag?('use-json')
          @swift_version = argv.option('swift-version', nil)
          @skip_import_validation = argv.flag?('skip-import-validation', false)
          @skip_tests = argv.flag?('skip-tests', false)
          @allow_overwrite = argv.flag?('overwrite', true)
          super
        end

        # Performs a full lint against the podspecs.
        #
        def validate_podspec_files
          UI.puts "\nValidating #{'spec'.pluralize(count)}".yellow
          podspec_files.each do |podspec|
            validator = Validator.new(podspec, @source_urls)
            validator.allow_warnings = @allow_warnings
            validator.use_frameworks = @use_frameworks
            validator.use_static_frameworks = @use_static_frameworks
            validator.use_modular_headers = @use_modular_headers
            validator.ignore_public_only_results = @private
            validator.swift_version = @swift_version
            validator.skip_import_validation = @skip_import_validation
            validator.skip_tests = @skip_tests
            begin
              validator.validate
            rescue => e
              raise Informative, "The `#{podspec}` specification does not validate." \
                                 "\n\n#{e.message}"
            end
            raise Informative, "The `#{podspec}` specification does not validate." unless validator.validated?
          end
        end

      end
    end
  end
end

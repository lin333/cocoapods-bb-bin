require 'cocoapods'

if Pod.match_version?('~> 1.4')
  require 'cocoapods-bb-bin/native/podfile'
  require 'cocoapods-bb-bin/native/installation_options'
  require 'cocoapods-bb-bin/native/specification'
  require 'cocoapods-bb-bin/native/path_source'
  require 'cocoapods-bb-bin/native/analyzer'
  require 'cocoapods-bb-bin/native/installer'
  require 'cocoapods-bb-bin/native/podfile_generator'
  require 'cocoapods-bb-bin/native/pod_source_installer'
  require 'cocoapods-bb-bin/native/linter'
  require 'cocoapods-bb-bin/native/resolver'
  require 'cocoapods-bb-bin/native/source'
  require 'cocoapods-bb-bin/native/validator' #使用cocoapods-1.11.2
  require 'cocoapods-bb-bin/native/acknowledgements'
  require 'cocoapods-bb-bin/native/sandbox_analyzer'
  require 'cocoapods-bb-bin/native/podspec_finder'
  require 'cocoapods-bb-bin/native/file_accessor'
  require 'cocoapods-bb-bin/native/pod_target_installer'
  require 'cocoapods-bb-bin/native/target_validator'
  require 'cocoapods-bb-bin/native/push' # 支持modulemap & swift与oc工程混编

end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cocoapods-bb-bin/gem_version.rb'

Gem::Specification.new do |spec|
  spec.name          = 'cocoapods-bb-bin'
  spec.version       = CBin::VERSION
  spec.authors       = ['humin']
  spec.email         = ['humin1102@126.com']
  spec.description   = %q{cocoapods-bb-bin is a plugin which helps develpers switching pods between source code and binary.}
  spec.summary       = %q{cocoapods-bb-bin is a plugin which helps develpers switching pods between source code and binary.}
  spec.homepage      = 'https://github.com/humin1102/cocoapods-bb-bin'
  spec.license       = 'MIT'

  spec.files = Dir["lib/**/*.rb","spec/**/*.rb","lib/**/*.plist"] + %w{README.md LICENSE.txt }
  #spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'parallel'
  spec.add_dependency "cocoapods", '>= 1.10.0', '< 2.0'
  spec.add_dependency "cocoapods-generate", '~>2.0.1'#'>= 2.0.1', '< 3.0'
  spec.add_dependency 'cocoapods-bb-xcframework'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
end

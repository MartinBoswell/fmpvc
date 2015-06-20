# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'fmpvc/version'

Gem::Specification.new do |spec|
  spec.name          = "fmpvc"
  spec.version       = FMPVC::VERSION
  spec.authors       = ["Martin S. Boswell"]
  spec.email         = ["mboswell@me.com"]

  spec.summary       = %q{Create a text version of the design elements of a FileMaker database.}
  spec.description   = %q{Process FileMaker Pro Advanced's Database Design Report (DDR) to produce textual representations of the design objects for use with version control systems, text editors, etc.}
  spec.homepage      = "http://rubygems.org/gems/fmpvc"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',    '~> 1.9'
  spec.add_development_dependency 'rake',       '~> 10.0'
  spec.add_development_dependency 'rspec'
  
  spec.add_dependency 'nokogiri',               '~> 1.6.6'
  spec.add_dependency 'activesupport',          '~> 4.2'

end

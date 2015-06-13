# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'fmpvc/version'

Gem::Specification.new do |spec|
  spec.name          = "fmpvc"
  spec.version       = FMPVC::VERSION
  spec.authors       = ["Martin S. Boswell"]
  spec.email         = ["mboswell@me.com"]

  spec.summary       = %q{Create a text version of FileMaker's DDR for use with a version control system.}
  spec.description   = %q{Process FileMaker Pro Advanced's Database Design Report (DDR) to produce textual representations of the objects with the intention of using this output in a version control system.}
  spec.homepage      = "TODO: Put your gem's website or public repo URL here."
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler',    '~> 1.9'
  spec.add_development_dependency 'rake',       '~> 10.0'
  
  spec.add_dependency 'nokogiri',               '~> 1.6.6'
  spec.add_dependency 'activesupport',          '~> 4.2'

end

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'kitchen/driver/metal_version.rb'

Gem::Specification.new do |gem|
  gem.name          = "kitchen-metal"
  gem.version       = Kitchen::Driver::METAL_VERSION
  gem.license       = 'Apache 2.0'
  gem.authors       = ["Douglas Triggs"]
  gem.email         = ["doug@getchef.com"]
  gem.description   = "Kitchen::Driver::Metal - A Metal Driver for Test Kitchen."
  gem.summary       = gem.description
  gem.homepage      = "https://github.com/test-kitchen/kitchen-metal/"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = []
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_dependency 'test-kitchen', '~> 1.1'
end

Gem::Specification.new do |gem|
  gem.name          = 'rbell'
  gem.version       = '0.0.1'
  gem.summary       = "Ruby's Embedded LL(1) parser generator"
  gem.description   = 'Ruby DSL to build LL(1) parsers'
  gem.license       = 'MIT'
  gem.authors       = %w'P3t3rU5 SilverPhoenix'
  gem.email         = %w'pedro.at.miranda@gmail.com'
  gem.homepage      = 'https://github.com/SilverPhoenix99/rbell'
  gem.require_paths = %w'lib'
  gem.files         = Dir['{lib/**/*.rb,*.md}']
  gem.add_development_dependency 'rspec', '~> 3.5'
end

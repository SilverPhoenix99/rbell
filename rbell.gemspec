Gem::Specification.new do |gem|
  gem.name          = 'rbell'
  gem.version       = '0.0.1'
  gem.summary       = ''
  gem.description   = ''
  gem.license       = 'MIT'
  gem.authors       = %w'P3t3rU5 SilverPhoenix'
  gem.email         = %w'pedro.at.miranda@gmail.com'
  gem.homepage      = 'https://github.com/SilverPhoenix99/rbell'
  gem.require_paths = %w'lib'
  gem.files         = Dir['{lib/**/*.rb,*.md}']
  gem.add_dependency 'rltk', '~> 3.0'
  gem.add_development_dependency 'rspec', '~> 3.5'
end

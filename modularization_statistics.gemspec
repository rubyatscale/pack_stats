Gem::Specification.new do |spec|
  spec.name          = 'modularization_statistics'
  spec.version       = '2.0.0'
  spec.authors       = ['Gusto Engineers']
  spec.email         = ['dev@gusto.com']

  spec.summary       = 'A gem to collect statistics about modularization progress in a Rails application using packwerk.'
  spec.description   = 'A gem to collect statistics about modularization progress in a Rails application using packwerk.'
  spec.homepage      = 'https://github.com/rubyatscale/modularization_statistics'
  spec.license       = 'MIT'

  if spec.respond_to?(:metadata)
    spec.metadata['homepage_uri'] = spec.homepage
    spec.metadata['source_code_uri'] = 'https://github.com/rubyatscale/modularization_statistics'
    spec.metadata['changelog_uri'] = 'https://github.com/rubyatscale/modularization_statistics/releases'
    spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
          'public gem pushes.'
  end

  spec.required_ruby_version = Gem::Requirement.new('>= 2.6.0')

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir['README.md', 'sorbet/**/*', 'lib/**/*']

  spec.require_paths = ['lib']

  spec.add_dependency 'code_teams'
  spec.add_dependency 'code_ownership'
  spec.add_dependency 'dogapi'
  spec.add_dependency 'parse_packwerk'
  spec.add_dependency 'sorbet-runtime'
  spec.add_dependency 'rubocop-packs'

  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'sorbet'
  spec.add_development_dependency 'tapioca'
end

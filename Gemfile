source 'https://rubygems.org'

# Specify your gem's dependencies in pack_stats.gemspec
gemspec

# activesupport 7.2.3.1+ patches CVEs while supporting Ruby >= 3.1 (the CI minimum).
# Version 8.x bumps connection_pool to 3.x which requires Ruby >= 3.2.
gem 'activesupport', '>= 7.2.3.1', '< 8'

# connection_pool 3.x requires Ruby >= 3.2; cap to 2.x so the lockfile
# stays compatible with the CI Ruby 3.1 matrix entry.
gem 'connection_pool', '< 3'

# frozen_string_literal: true

require 'bundler/setup'
require 'modularization_statistics'
require 'pry'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.around do |example|
    prefix = [File.basename($0), Process.pid].join('-') # rubocop:disable Style/SpecialGlobalVars
    tmpdir = Dir.mktmpdir(prefix)
    Dir.chdir(tmpdir) do
      example.run
    end
  ensure
    FileUtils.rm_rf(tmpdir)
  end
end

def write_file(path, content = '')
  pathname = Pathname.new(path)
  FileUtils.mkdir_p(pathname.dirname)
  pathname.write(content)
end

def sorbet_double(stubbed_class, attr_map = {})
  instance_double(stubbed_class, attr_map).tap do |dbl|
    allow(dbl).to receive(:is_a?) { |tested_class| stubbed_class.ancestors.include?(tested_class) }
  end
end

RSpec.shared_context 'team names are based off of file names' do
  before do
    allow(CodeOwnership).to receive(:for_file) do |filename|
      match = filename.match(/_(\d+)/)
      if match
        team_number = match[1]
        sorbet_double(Teams::Team, name: "Team #{team_number}")
      end
    end
  end
end

RSpec.shared_context 'only one team' do
  before do
    allow(CodeOwnership).to receive(:for_file).and_return(sorbet_double(Teams::Team, name: 'Some team'))
  end
end

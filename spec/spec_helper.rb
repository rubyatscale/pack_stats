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
        sorbet_double(CodeTeams::Team, name: "Team #{team_number}")
      end
    end
  end
end

RSpec.shared_context 'only one team' do
  before do
    allow(CodeOwnership).to receive(:for_file).and_return(sorbet_double(CodeTeams::Team, name: 'Some team'))
  end
end

RSpec::Matchers.define(:include_metric) do |expected_metric|
  match do |actual_metrics|
    @actual_metrics = actual_metrics
    @expected_metric = expected_metric
    @matching_metrics = actual_metrics.select { |actual_metric| actual_metric.name == expected_metric.name }
    @actual_metric = @matching_metrics.find { |matching_metric| matching_metric.count == expected_metric.count && expected_metric.tags.sort_by(&:key) == matching_metric.tags.sort_by(&:key) }
    @matching_metrics.any? && !@actual_metric.nil?
  end

  description do
    "to have a metric named `#{expected_metric.name}` with count of #{expected_metric.count} and tags of #{expected_metric.tags.map(&:to_s)}"
  end

  failure_message do
    if @matching_metrics.none?
      "Could not find metric with name `#{expected_metric.name}` Could only find metrics with names: \n\n#{@actual_metrics.sort_by(&:name).uniq.join("\n")}"
    else
      count_diff = "Actual count: #{@matching_metrics.map(&:count)}\nExpected count: #{expected_metric.count}"
      actual_tags = @matching_metrics.map { |matching_metric| matching_metric.tags.map(&:to_s) }
      expected_tags = expected_metric.tags.map(&:to_s)
      tags_diff = "Actual tags (not in expected): #{actual_tags.map { |actual| actual - expected_tags }}\nExpected tags (not in actual): #{expected_tags - actual_tags}"
      <<~FAILURE_MESSAGE
        Expected and actual metric `#{expected_metric.name}` are not equal. Found #{@matching_metrics.count} metrics with matching name `#{@expected_metric.name}`, but the properties are different
        #{count_diff}
        #{tags_diff}
      FAILURE_MESSAGE
    end
  end
end

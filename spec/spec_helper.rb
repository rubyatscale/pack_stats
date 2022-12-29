# frozen_string_literal: true

require 'bundler/setup'
require 'pack_stats'
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
    @metrics_with_same_name = actual_metrics.select { |actual_metric| actual_metric.name == expected_metric.name }
    @matching_metric = @metrics_with_same_name.find { |matching_metric| matching_metric.count == expected_metric.count && expected_metric.tags.sort_by(&:key) == matching_metric.tags.sort_by(&:key) }
    @metrics_with_same_name.any? && !@matching_metric.nil?
  end

  description do
    "to have a metric named `#{expected_metric.name}` with count of #{expected_metric.count} and tags of #{expected_metric.tags.map(&:to_s)}"
  end

  failure_message do
    if @metrics_with_same_name.none?
      "Could not find metric:\n\n#{expected_metric}\n\nCould only find metrics with names: \n\n#{@actual_metrics.sort_by(&:name).uniq.join("\n")}"
    else

      # We colorize each part of the output red (if there is no match) or green (if there is a partial match)
      colorized_metrics = @metrics_with_same_name.sort_by(&:name).map do |actual_metric|
        count_equal = actual_metric.count == expected_metric.count
        with_count = "with count #{actual_metric.count}"
        colorized_with_count = count_equal ? Rainbow(with_count).green : Rainbow(with_count).red

        tags = actual_metric.tags.sort_by(&:key).map do |tag|
          if expected_metric.tags.include?(tag)
            Rainbow(tag.to_s).green
          else
            Rainbow(tag.to_s).red
          end
        end

        "#{Rainbow(actual_metric.name).green} #{colorized_with_count}, with tags #{tags.join(', ')}"
      end

      "Could not find metric:\n\n#{expected_metric}\n\nCould only find metrics: \n\n#{colorized_metrics.join("\n")}"
    end
  end
end

def write_package_yml(
  pack_name,
  dependencies: [],
  enforce_dependencies: true,
  enforce_privacy: true,
  protections: {},
  global_namespaces: [],
  visible_to: [],
  owner: nil
)
  defaults = {
    'prevent_this_package_from_violating_its_stated_dependencies' => 'fail_on_new',
    'prevent_other_packages_from_using_this_packages_internals' => 'fail_on_new',
    'prevent_this_package_from_exposing_an_untyped_api' => 'fail_on_new',
    'prevent_this_package_from_creating_other_namespaces' => 'fail_on_new',
  }
  protections_with_defaults = defaults.merge(protections)
  metadata = { 'protections' => protections_with_defaults }

  if owner
    metadata.merge({ 'owner' => owner })
  end

  if global_namespaces
    metadata.merge({ 'global_namespaces' => global_namespaces })
  end

  package = ParsePackwerk::Package.new(
    name: pack_name,
    dependencies: dependencies,
    enforce_dependencies: enforce_dependencies,
    enforce_privacy: enforce_privacy,
    metadata: metadata,
    config: {},
  )

  ParsePackwerk.write_package_yml!(package)
end

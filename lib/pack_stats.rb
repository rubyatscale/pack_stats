# typed: strict

require 'sorbet-runtime'
require 'json'
require 'yaml'
require 'benchmark'
require 'code_teams'
require 'code_ownership'
require 'pathname'
require 'packs'
require 'pack_stats/private'
require 'pack_stats/private/source_code_file'
require 'pack_stats/private/datadog_reporter'
require 'parse_packwerk'
require 'pack_stats/tag'
require 'pack_stats/tags'
require 'pack_stats/gauge_metric'

module PackStats
  extend T::Sig

  ROOT_PACKAGE_NAME = T.let('root'.freeze, String)

  DEFAULT_COMPONENTIZED_SOURCE_CODE_LOCATIONS = T.let(
    [
      Pathname.new('components'),
      Pathname.new('gems'),
    ].freeze, T::Array[Pathname]
  )

  sig do
    params(
      datadog_client: Dogapi::Client,
      app_name: String,
      source_code_pathnames: T::Array[Pathname],
      componentized_source_code_locations: T::Array[Pathname],
      report_time: Time,
      verbose: T::Boolean,
      # See note on get_metrics
      packaged_source_code_locations: T.nilable(T::Array[Pathname]),
      # See note on get_metrics
      use_gusto_legacy_names: T::Boolean,
      # See note on get_metrics
      max_enforcements_tag_value: T::Boolean
    ).void
  end
  def self.report_to_datadog!(
    datadog_client:,
    app_name:,
    source_code_pathnames:,
    componentized_source_code_locations: DEFAULT_COMPONENTIZED_SOURCE_CODE_LOCATIONS,
    report_time: Time.now, # rubocop:disable Rails/TimeZone
    verbose: false,
    packaged_source_code_locations: [],
    use_gusto_legacy_names: false,
    max_enforcements_tag_value: false
  )

    all_metrics = self.get_metrics(
      source_code_pathnames: source_code_pathnames,
      componentized_source_code_locations: componentized_source_code_locations,
      app_name: app_name,
      use_gusto_legacy_names: use_gusto_legacy_names,
      max_enforcements_tag_value: max_enforcements_tag_value,
    )

    # This helps us debug what metrics are being sent
    if verbose
      all_metrics.each do |metric|
        puts "Sending metric: #{metric}"
      end
    end

    if use_gusto_legacy_names
      all_metrics = Private.convert_metrics_to_legacy(all_metrics)
    end

    Private::DatadogReporter.report!(
      datadog_client: datadog_client,
      report_time: report_time,
      metrics: all_metrics
    )
  end

  sig do
    params(
      source_code_pathnames: T::Array[Pathname],
      componentized_source_code_locations: T::Array[Pathname],
      app_name: String,
      # This field is deprecated
      packaged_source_code_locations: T.nilable(T::Array[Pathname]),
      # It is not recommended to set this to true.
      # Gusto uses this to preserve historical trends in Dashboards as the names of
      # things changed, but new dashboards can use names that better match current tooling conventions.
      # The behavior of setting this parameter to true might change without warning
      use_gusto_legacy_names: T::Boolean,
      # You can set this to `true` to tag all metrics with `max_enforcements:true`.
      # This is useful if you want to submit two sets of metrics:
      # Once with the violation counts as configured in the app
      # Another time with the violation counts after turning on all enforcements and running `bin/packwerk update`.
      max_enforcements_tag_value: T::Boolean
    ).returns(T::Array[GaugeMetric])
  end
  def self.get_metrics(
    source_code_pathnames:,
    componentized_source_code_locations:,
    app_name:,
    packaged_source_code_locations: [],
    use_gusto_legacy_names: false,
    max_enforcements_tag_value: false
  )

    GaugeMetric.set_max_enforcements_tag(max_enforcements_tag_value)

    all_metrics = Private::DatadogReporter.get_metrics(
      source_code_files: source_code_files(
        source_code_pathnames: source_code_pathnames,
        componentized_source_code_locations: componentized_source_code_locations,
      ),
      app_name: app_name
    )

    if use_gusto_legacy_names
      all_metrics = Private.convert_metrics_to_legacy(all_metrics)
    end

    all_metrics
  end

  sig do
    params(
      source_code_pathnames: T::Array[Pathname],
      componentized_source_code_locations: T::Array[Pathname],
    ).returns(T::Array[Private::SourceCodeFile])
  end
  def self.source_code_files(
    source_code_pathnames:,
    componentized_source_code_locations:
  )

    # Sorbet has the wrong signatures for `Pathname#find`, whoops!
    componentized_file_set = Set.new(componentized_source_code_locations.select(&:exist?).flat_map { |pathname| T.unsafe(pathname).find.to_a })

    packaged_file_set = Packs.all.flat_map do |pack|
      pack.relative_path.find.to_a
    end

    packaged_file_set = Set.new(packaged_file_set)

    source_code_pathnames.map do |pathname|
      componentized_file = componentized_file_set.include?(pathname)
      packaged_file = packaged_file_set.include?(pathname)

      Private::SourceCodeFile.new(
        pathname: pathname,
        team_owner: CodeOwnership.for_file(pathname.to_s),
        is_componentized_file: componentized_file,
        is_packaged_file: packaged_file
      )
    end
  end

  private_class_method :source_code_files
end

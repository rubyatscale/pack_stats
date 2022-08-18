# typed: strict
# frozen_string_literal: true

require 'dogapi'
require 'modularization_statistics/private/metrics'
require 'modularization_statistics/private/metrics/files'
require 'modularization_statistics/private/metrics/public_usage'
require 'modularization_statistics/private/metrics/protection_usage'
require 'modularization_statistics/private/metrics/packages'

module ModularizationStatistics
  module Private
    class DatadogReporter
      extend T::Sig

      sig do
        params(
          source_code_files: T::Array[SourceCodeFile],
          app_name: String
        ).returns(T::Array[GaugeMetric])
      end
      def self.get_metrics(source_code_files:, app_name:)
        all_metrics = T.let([], T::Array[GaugeMetric])
        all_metrics += Metrics::Files.get_metrics(source_code_files, app_name)
        packages = ParsePackwerk.all
        all_metrics += Metrics::Packages.get_package_metrics(packages, app_name)
        all_metrics += get_package_metrics_by_team(packages, app_name)

        all_metrics
      end

      sig do
        params(
          datadog_client: Dogapi::Client,
          # Since `gauge` buckets data points we need to use the same time for all API calls
          # to ensure they fall into the same bucket.
          report_time: Time,
          metrics: T::Array[GaugeMetric]
        ).void
      end
      def self.report!(datadog_client:, report_time:, metrics:)
        #
        # Batching the metrics sends a post request to DD
        # we want to split this up into chunks of 1000 so that as we add more metrics,
        # our payload is not rejected for being too large
        #
        metrics.each_slice(1000).each do |metric_slice|
          datadog_client.batch_metrics do
            metric_slice.each do |metric|
              datadog_client.emit_points(metric.name, [[report_time, metric.count]], type: 'gauge', tags: metric.tags.map(&:to_s))
            end
          end
        end
      end

      sig do
        params(
          all_packages: T::Array[ParsePackwerk::Package],
          app_name: String
        ).returns(T::Array[GaugeMetric])
      end
      def self.get_package_metrics_by_team(all_packages, app_name)
        all_metrics = T.let([], T::Array[GaugeMetric])
        app_level_tag = Tag.for('app', app_name)
        all_protected_packages = all_packages.map { |p| PackageProtections::ProtectedPackage.from(p) }
        all_protected_packages.group_by { |protected_package| CodeOwnership.for_package(protected_package.original_package)&.name }.each do |team_name, protected_packages_by_team|
          # We look at `all_packages` because we care about ALL inbound violations across all teams
          inbound_violations_by_package = all_protected_packages.flat_map(&:violations).group_by(&:to_package_name)

          team_tags = Metrics.tags_for_team(team_name) + [app_level_tag]
          all_metrics << GaugeMetric.for('by_team.all_packages.count', protected_packages_by_team.count, team_tags)
          all_metrics += Metrics::ProtectionUsage.get_protections_metrics('by_team', protected_packages_by_team, team_tags)
          all_metrics += Metrics::PublicUsage.get_public_usage_metrics('by_team', protected_packages_by_team.map(&:original_package), team_tags)

          all_metrics << GaugeMetric.for('by_team.notify_on_package_yml_changes.count', protected_packages_by_team.count { |p| p.metadata['notify_on_package_yml_changes'] }, team_tags)
          all_metrics << GaugeMetric.for('by_team.notify_on_new_violations.count', protected_packages_by_team.count { |p| p.metadata['notify_on_new_violations'] }, team_tags)

          #
          # VIOLATIONS (implicit dependencies)
          #
          outbound_violations = protected_packages_by_team.flat_map(&:violations)
          # Here we only look at packages_by_team because we only care about inbound violations onto packages for this team
          inbound_violations = protected_packages_by_team.flat_map { |package| inbound_violations_by_package[package.name] || [] }
          all_dependency_violations = (outbound_violations + inbound_violations).select(&:dependency?)
          all_privacy_violations = (outbound_violations + inbound_violations).select(&:privacy?)

          all_metrics << GaugeMetric.for('by_team.dependency_violations.count', Metrics.file_count(all_dependency_violations), team_tags)
          all_metrics << GaugeMetric.for('by_team.privacy_violations.count', Metrics.file_count(all_privacy_violations), team_tags)

          all_metrics << GaugeMetric.for('by_team.outbound_dependency_violations.count', Metrics.file_count(outbound_violations.select(&:dependency?)), team_tags)
          all_metrics << GaugeMetric.for('by_team.inbound_dependency_violations.count', Metrics.file_count(inbound_violations.select(&:dependency?)), team_tags)

          all_metrics << GaugeMetric.for('by_team.outbound_privacy_violations.count', Metrics.file_count(outbound_violations.select(&:privacy?)), team_tags)
          all_metrics << GaugeMetric.for('by_team.inbound_privacy_violations.count', Metrics.file_count(inbound_violations.select(&:privacy?)), team_tags)

          all_metrics << GaugeMetric.for('by_team.has_readme.count', protected_packages_by_team.count { |protected_package| Metrics.has_readme?(protected_package.original_package) }, team_tags)

          grouped_outbound_violations = outbound_violations.group_by do |violation|
            to_package = ParsePackwerk.find(violation.to_package_name)
            if to_package.nil?
              raise StandardError, "Could not find matching package #{violation.to_package_name}"
            end

            CodeOwnership.for_package(to_package)&.name
          end

          grouped_outbound_violations.each do |to_team_name, violations|
            tags = team_tags + Metrics.tags_for_to_team(to_team_name)
            all_metrics << GaugeMetric.for('by_team.outbound_dependency_violations.per_team.count', Metrics.file_count(violations.select(&:dependency?)), tags)
            all_metrics << GaugeMetric.for('by_team.outbound_privacy_violations.per_team.count', Metrics.file_count(violations.select(&:privacy?)), tags)
          end
        end

        all_metrics
      end
    end
  end
end

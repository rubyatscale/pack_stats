# typed: strict
# frozen_string_literal: true

require 'dogapi'
require 'modularization_statistics/private/metrics'
require 'modularization_statistics/private/metrics/files'

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
        all_metrics += get_package_metrics(packages, app_name)
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

      sig { params(package: ParsePackwerk::Package, app_name: String).returns(T::Array[Tag]) }
      def self.tags_for_package(package, app_name)
        [
          Tag.new(key: 'package', value: humanized_package_name(package.name)),
          Tag.new(key: 'app', value: app_name),
          *Metrics.tags_for_team(CodeOwnership.for_package(package)&.name),
        ]
      end

      sig { params(team_name: T.nilable(String)).returns(T::Array[Tag]) }
      def self.tags_for_to_team(team_name)
        [Tag.for('to_team', team_name || Metrics::UNKNOWN_OWNER)]
      end

      private_class_method :tags_for_package

      sig do
        params(
          packages: T::Array[ParsePackwerk::Package],
          app_name: String
        ).returns(T::Array[GaugeMetric])
      end
      def self.get_package_metrics(packages, app_name)
        all_metrics = []
        app_level_tag = Tag.for('app', app_name)
        package_tags = T.let([app_level_tag], T::Array[Tag])
        protected_packages = packages.map { |p| PackageProtections::ProtectedPackage.from(p) }

        all_metrics << GaugeMetric.for('all_packages.count', packages.count, package_tags)
        all_metrics << GaugeMetric.for('all_packages.dependencies.count', packages.sum { |package| package.dependencies.count }, package_tags)
        all_metrics << GaugeMetric.for('all_packages.dependency_violations.count', protected_packages.sum { |package| file_count(package.violations.select(&:dependency?)) }, package_tags)
        all_metrics << GaugeMetric.for('all_packages.privacy_violations.count', protected_packages.sum { |package| file_count(package.violations.select(&:privacy?)) }, package_tags)
        all_metrics << GaugeMetric.for('all_packages.enforcing_dependencies.count', packages.count(&:enforces_dependencies?), package_tags)
        all_metrics << GaugeMetric.for('all_packages.enforcing_privacy.count', packages.count(&:enforces_privacy?), package_tags)

        all_metrics << GaugeMetric.for('all_packages.notify_on_package_yml_changes.count', packages.count { |p| p.metadata['notify_on_package_yml_changes'] }, package_tags)
        all_metrics << GaugeMetric.for('all_packages.notify_on_new_violations.count', packages.count { |p| p.metadata['notify_on_new_violations'] }, package_tags)

        all_metrics << GaugeMetric.for('all_packages.with_violations.count', protected_packages.count { |package| package.violations.any? }, package_tags)
        all_metrics += self.get_public_usage_metrics('all_packages', packages, package_tags)
        all_metrics << GaugeMetric.for('all_packages.has_readme.count', packages.count { |package| has_readme?(package) }, package_tags)

        all_metrics += self.get_protections_metrics('all_packages', protected_packages, package_tags)
        all_metrics << GaugeMetric.for('all_packages.package_based_file_ownership.count', packages.count { |package| !package.metadata['owner'].nil? }, package_tags)

        inbound_violations_by_package = protected_packages.flat_map(&:violations).group_by(&:to_package_name)

        protected_packages.each do |protected_package|
          package = protected_package.original_package
          package_tags = tags_for_package(package, app_name)

          #
          # VIOLATIONS (implicit dependencies)
          #
          outbound_violations = protected_package.violations
          inbound_violations = inbound_violations_by_package[package.name] || []
          all_dependency_violations = (outbound_violations + inbound_violations).select(&:dependency?)
          all_privacy_violations = (outbound_violations + inbound_violations).select(&:privacy?)

          all_metrics << GaugeMetric.for('by_package.dependency_violations.count', file_count(all_dependency_violations), package_tags)
          all_metrics << GaugeMetric.for('by_package.privacy_violations.count', file_count(all_privacy_violations), package_tags)

          all_metrics << GaugeMetric.for('by_package.outbound_dependency_violations.count', file_count(outbound_violations.select(&:dependency?)), package_tags)
          all_metrics << GaugeMetric.for('by_package.inbound_dependency_violations.count', file_count(inbound_violations.select(&:dependency?)), package_tags)

          all_metrics << GaugeMetric.for('by_package.outbound_privacy_violations.count', file_count(outbound_violations.select(&:privacy?)), package_tags)
          all_metrics << GaugeMetric.for('by_package.inbound_privacy_violations.count', file_count(inbound_violations.select(&:privacy?)), package_tags)

          all_metrics += self.get_public_usage_metrics('by_package', [package], package_tags)

          protected_package.violations.group_by(&:to_package_name).each do |to_package_name, violations|
            to_package = ParsePackwerk.find(to_package_name)
            if to_package.nil?
              raise StandardError, "Could not find matching package #{to_package_name}"
            end

            tags = package_tags + [Tag.for('to_package', humanized_package_name(to_package_name))] + tags_for_to_team(CodeOwnership.for_package(to_package)&.name)
            all_metrics << GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', file_count(violations.select(&:dependency?)), tags)
            all_metrics << GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', file_count(violations.select(&:privacy?)), tags)
          end
        end

        inbound_explicit_dependency_by_package = {}
        packages.each do |package|
          package.dependencies.each do |explicit_dependency|
            inbound_explicit_dependency_by_package[explicit_dependency] ||= []
            inbound_explicit_dependency_by_package[explicit_dependency] << package.name
          end
        end

        packages.each do |package| # rubocop:disable Style/CombinableLoops
          package_tags = tags_for_package(package, app_name)

          #
          # EXPLICIT DEPENDENCIES
          #
          package.dependencies.each do |explicit_dependency|
            to_package = ParsePackwerk.find(explicit_dependency)
            if to_package.nil?
              raise StandardError, "Could not find matching package #{explicit_dependency}"
            end

            tags = package_tags + [Tag.for('to_package', humanized_package_name(explicit_dependency))] + tags_for_to_team(CodeOwnership.for_package(to_package)&.name)
            all_metrics << GaugeMetric.for('by_package.outbound_explicit_dependencies.per_package.count', 1, tags)
          end

          all_metrics << GaugeMetric.for('by_package.outbound_explicit_dependencies.count', package.dependencies.count, package_tags)
          all_metrics << GaugeMetric.for('by_package.inbound_explicit_dependencies.count', inbound_explicit_dependency_by_package[package.name]&.count || 0, package_tags)
        end

        all_metrics
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
          all_metrics += self.get_protections_metrics('by_team', protected_packages_by_team, team_tags)
          all_metrics += self.get_public_usage_metrics('by_team', protected_packages_by_team.map(&:original_package), team_tags)

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

          all_metrics << GaugeMetric.for('by_team.dependency_violations.count', file_count(all_dependency_violations), team_tags)
          all_metrics << GaugeMetric.for('by_team.privacy_violations.count', file_count(all_privacy_violations), team_tags)

          all_metrics << GaugeMetric.for('by_team.outbound_dependency_violations.count', file_count(outbound_violations.select(&:dependency?)), team_tags)
          all_metrics << GaugeMetric.for('by_team.inbound_dependency_violations.count', file_count(inbound_violations.select(&:dependency?)), team_tags)

          all_metrics << GaugeMetric.for('by_team.outbound_privacy_violations.count', file_count(outbound_violations.select(&:privacy?)), team_tags)
          all_metrics << GaugeMetric.for('by_team.inbound_privacy_violations.count', file_count(inbound_violations.select(&:privacy?)), team_tags)

          all_metrics << GaugeMetric.for('by_team.has_readme.count', protected_packages_by_team.count { |protected_package| has_readme?(protected_package.original_package) }, team_tags)

          grouped_outbound_violations = outbound_violations.group_by do |violation|
            to_package = ParsePackwerk.find(violation.to_package_name)
            if to_package.nil?
              raise StandardError, "Could not find matching package #{violation.to_package_name}"
            end

            CodeOwnership.for_package(to_package)&.name
          end

          grouped_outbound_violations.each do |to_team_name, violations|
            tags = team_tags + tags_for_to_team(to_team_name)
            all_metrics << GaugeMetric.for('by_team.outbound_dependency_violations.per_team.count', file_count(violations.select(&:dependency?)), tags)
            all_metrics << GaugeMetric.for('by_team.outbound_privacy_violations.per_team.count', file_count(violations.select(&:privacy?)), tags)
          end
        end

        all_metrics
      end

      private_class_method :get_package_metrics

      sig do
        params(
          metric_name_suffix: String,
          tags: T::Array[Tag],
          files: T::Array[SourceCodeFile]
        ).returns(T::Array[GaugeMetric])
      end
      def self.get_file_metrics(metric_name_suffix, tags, files)
        [
          GaugeMetric.for("component_files.#{metric_name_suffix}", files.count(&:componentized_file?), tags),
          GaugeMetric.for("packaged_files.#{metric_name_suffix}", files.count(&:packaged_file?), tags),
          GaugeMetric.for("all_files.#{metric_name_suffix}", files.count, tags),
        ]
      end

      private_class_method :get_file_metrics

      sig { params(prefix: String, protected_packages: T::Array[PackageProtections::ProtectedPackage], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
      def self.get_protections_metrics(prefix, protected_packages, package_tags)
        PackageProtections.all.flat_map do |protection|
          PackageProtections::ViolationBehavior.each_value.map do |violation_behavior|
            # https://github.com/Gusto/package_protections/pull/42 changed the public API of these violation behaviors.
            # To preserve our ability to understand historical trends, we map to the old values.
            # This allows our dashboards to continue to operate as expected.
            # Note if we ever open source mod stats, we should probably inject this behavior so that new clients can see the new keys in their metrics.
            violation_behavior_map = {
              PackageProtections::ViolationBehavior::FailOnAny => 'fail_the_build_on_any_instances',
              PackageProtections::ViolationBehavior::FailNever => 'no',
              PackageProtections::ViolationBehavior::FailOnNew => 'fail_the_build_if_new_instances_appear',
            }
            violation_behavior_name = violation_behavior_map[violation_behavior]
            metric_name = "#{prefix}.#{protection.identifier}.#{violation_behavior_name}.count"
            count_of_packages = protected_packages.count { |p| p.violation_behavior_for(protection.identifier) == violation_behavior }
            GaugeMetric.for(metric_name, count_of_packages, package_tags)
          end
        end
      end

      sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
      def self.get_public_usage_metrics(prefix, packages, package_tags)
        packages_except_for_root = packages.reject { |package| package.name == ParsePackwerk::ROOT_PACKAGE_NAME }
        all_files = packages_except_for_root.flat_map do |package|
          package.directory.glob('**/**.rb')
        end

        all_public_files = T.let([], T::Array[Pathname])
        is_using_public_directory = 0
        packages_except_for_root.each do |package|
          public_files = package.directory.glob('app/public/**/**.rb')
          all_public_files += public_files
          is_using_public_directory += 1 if public_files.any?
        end

        # In Datadog, can divide public files by all files to get the ratio.
        # This is not a metric that we are targeting -- its for observability and reflection only.
        [
          GaugeMetric.for("#{prefix}.all_files.count", all_files.count, package_tags),
          GaugeMetric.for("#{prefix}.public_files.count", all_public_files.count, package_tags),
          GaugeMetric.for("#{prefix}.using_public_directory.count", is_using_public_directory, package_tags),
        ]
      end

      sig { params(package: ParsePackwerk::Package).returns(T::Boolean) }
      def self.has_readme?(package)
        package.directory.join('README.md').exist?
      end

      sig { params(violations: T::Array[ParsePackwerk::Violation]).returns(Integer) }
      def self.file_count(violations)
        violations.sum { |v| v.files.count }
      end

      sig { params(name: String).returns(String) }
      def self.humanized_package_name(name)
        if name == ParsePackwerk::ROOT_PACKAGE_NAME
          'root'
        else
          name
        end
      end
    end
  end
end

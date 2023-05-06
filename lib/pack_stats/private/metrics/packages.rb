# typed: strict
# frozen_string_literal: true

module PackStats
  module Private
    module Metrics
      class Packages
        extend T::Sig

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

          all_metrics << GaugeMetric.for('all_packages.count', packages.count, package_tags)
          all_metrics << GaugeMetric.for('all_packages.dependencies.count', packages.sum { |package| package.dependencies.count }, package_tags)
          all_metrics << GaugeMetric.for('all_packages.dependency_violations.count', packages.sum { |package| Metrics.file_count(package.violations.select(&:dependency?)) }, package_tags)
          all_metrics << GaugeMetric.for('all_packages.privacy_violations.count', packages.sum { |package| Metrics.file_count(package.violations.select(&:privacy?)) }, package_tags)

          all_metrics += Metrics::PublicUsage.get_public_usage_metrics('all_packages', packages, package_tags)
          all_metrics << GaugeMetric.for('all_packages.has_readme.count', packages.count { |package| Metrics.has_readme?(package) }, package_tags)

          all_metrics += Metrics::PackwerkCheckerUsage.get_checker_metrics('all_packages', packages, package_tags)
          all_metrics += Metrics::RubocopUsage.get_metrics('all_packages', packages, package_tags)
          all_metrics << GaugeMetric.for('all_packages.package_based_file_ownership.count', packages.count { |package| !package.metadata['owner'].nil? }, package_tags)

          inbound_violations_by_package = packages.flat_map(&:violations).group_by(&:to_package_name)

          packages.each do |package|
            package_tags = Metrics.tags_for_package(package, app_name)

            #
            # VIOLATIONS (implicit dependencies)
            #
            outbound_violations = package.violations
            inbound_violations = inbound_violations_by_package[package.name] || []
            all_dependency_violations = outbound_violations.select(&:dependency?)
            all_privacy_violations = inbound_violations.select(&:privacy?)

            all_metrics << GaugeMetric.for('by_package.dependency_violations.count', Metrics.file_count(all_dependency_violations), package_tags)
            all_metrics << GaugeMetric.for('by_package.privacy_violations.count', Metrics.file_count(all_privacy_violations), package_tags)
            all_metrics += Metrics::PublicUsage.get_public_usage_metrics('by_package', [package], package_tags)

            outbound_violations.group_by(&:to_package_name).each do |to_package_name, violations|
              to_package = ParsePackwerk.find(to_package_name)
              if to_package.nil?
                raise StandardError, "Could not find matching package #{to_package_name}"
              end

              tags = package_tags + [Tag.for('other_package', Metrics.humanized_package_name(to_package_name))] + Metrics.tags_for_other_team(Private.package_owner(to_package))
              all_metrics << GaugeMetric.for('by_package.dependency_violations.per_package.count', Metrics.file_count(violations.select(&:dependency?)), tags)
            end

            packages.each do |other_package|
              violations = other_package.violations.select{|v| v.to_package_name == other_package.name}
              tags = package_tags + [Tag.for('other_package', Metrics.humanized_package_name(other_package.name))] + Metrics.tags_for_other_team(Private.package_owner(other_package))
              all_metrics << GaugeMetric.for('by_package.privacy_violations.per_package.count', Metrics.file_count(violations.select(&:privacy?)), tags)
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
            package_tags = Metrics.tags_for_package(package, app_name)

            #
            # EXPLICIT DEPENDENCIES
            #
            package.dependencies.each do |explicit_dependency|
              to_package = ParsePackwerk.find(explicit_dependency)
              if to_package.nil?
                raise StandardError, "Could not find matching package #{explicit_dependency}"
              end

              owner = Private.package_owner(to_package)
              tags = package_tags + [Tag.for('other_package', Metrics.humanized_package_name(explicit_dependency))] + Metrics.tags_for_other_team(owner)
              all_metrics << GaugeMetric.for('by_package.outbound_explicit_dependencies.per_package.count', 1, tags)
            end

            all_metrics << GaugeMetric.for('by_package.outbound_explicit_dependencies.count', package.dependencies.count, package_tags)
            all_metrics << GaugeMetric.for('by_package.inbound_explicit_dependencies.count', inbound_explicit_dependency_by_package[package.name]&.count || 0, package_tags)
          end

          all_metrics
        end
      end
    end
  end
end

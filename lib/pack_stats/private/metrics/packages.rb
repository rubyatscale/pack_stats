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

          PackwerkCheckerUsage::CHECKERS.each do |checker|
            violation_count = packages.sum { |package| Metrics.file_count(package.violations.select{|v| v.type == checker.violation_type}) }
            tags = package_tags + [checker.violation_type_tag]
            all_metrics << GaugeMetric.for("all_packages.violations.count", violation_count, tags)
          end

          all_metrics += Metrics::PublicUsage.get_public_usage_metrics('all_packages', packages, package_tags)
          all_metrics << GaugeMetric.for('all_packages.has_readme.count', packages.count { |package| Metrics.has_readme?(package) }, package_tags)

          all_metrics += Metrics::PackwerkCheckerUsage.get_checker_metrics('all_packages', packages, package_tags)
          all_metrics += Metrics::RubocopUsage.get_metrics('all_packages', packages, package_tags)
          all_metrics << GaugeMetric.for('all_packages.package_based_file_ownership.count', packages.count { |package| !package.metadata['owner'].nil? }, package_tags)

          inbound_violations_by_package = packages.flat_map(&:violations).group_by(&:to_package_name)

          packages.each do |package|
            package_tags = Metrics.tags_for_package(package, app_name)
            all_metrics += Metrics::PublicUsage.get_public_usage_metrics('by_package', [package], package_tags)

            outbound_violations = package.violations
            inbound_violations = inbound_violations_by_package[package.name] || []

            PackwerkCheckerUsage::CHECKERS.each do |checker|
              direction = checker.direction

              case direction
              when PackwerkCheckerUsage::Direction::Outbound
                all_violations_of_type = outbound_violations.select { |v| v.type == checker.violation_type } 

                packages.each do |other_package|
                  violations = package.violations.select{|v| v.to_package_name == other_package.name && v.type == checker.violation_type }

                  tags = package_tags + [
                    Tag.for('other_package', Metrics.humanized_package_name(other_package.name)),
                    *Metrics.tags_for_other_team(Private.package_owner(other_package)),
                    checker.violation_type_tag
                  ]

                  all_metrics << GaugeMetric.for("by_package.violations.by_other_package.count", Metrics.file_count(violations), tags)
                end
              when PackwerkCheckerUsage::Direction::Inbound
                all_violations_of_type = inbound_violations.select { |v| v.type == checker.violation_type } 

                packages.each do |other_package|
                  violations = other_package.violations.select{|v| v.to_package_name == other_package.name && v.type == checker.violation_type }
                  tags = package_tags + [
                    Tag.for('other_package', Metrics.humanized_package_name(other_package.name)),
                    *Metrics.tags_for_other_team(Private.package_owner(other_package)),
                    checker.violation_type_tag
                  ]

                  all_metrics << GaugeMetric.for("by_package.violations.by_other_package.count", Metrics.file_count(violations), tags)
                end
              else
                T.absurd(direction)
              end

              tags = package_tags + [checker.violation_type_tag]
              all_metrics << GaugeMetric.for("by_package.violations.count", Metrics.file_count(all_violations_of_type), tags)
            end
          end

          all_metrics += Metrics::Dependencies.get_metrics('by_package', packages, app_name)

          all_metrics
        end
      end
    end
  end
end

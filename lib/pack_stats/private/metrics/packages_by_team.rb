# typed: strict
# frozen_string_literal: true

module PackStats
  module Private
    module Metrics
      class PackagesByTeam
        extend T::Sig

        sig do
          params(
            all_packages: T::Array[ParsePackwerk::Package],
            app_name: String
          ).returns(T::Array[GaugeMetric])
        end
        def self.get_package_metrics_by_team(all_packages, app_name)
          all_metrics = T.let([], T::Array[GaugeMetric])
          app_level_tag = Tag.for('app', app_name)

          
          all_packages.group_by { |package| Private.package_owner(package) }.each do |team_name, packages_for_team|
            team_tags = Metrics.tags_for_team(team_name) + [app_level_tag]
            all_metrics << GaugeMetric.for('by_team.all_packages.count', packages_for_team.count, team_tags)
            all_metrics += Metrics::PackwerkCheckerUsage.get_checker_metrics('by_team', packages_for_team, team_tags)
            all_metrics += Metrics::PublicUsage.get_public_usage_metrics('by_team', packages_for_team, team_tags)
            all_metrics << GaugeMetric.for('by_team.has_readme.count', packages_for_team.count { |package| Metrics.has_readme?(package) }, team_tags)

            outbound_violations = packages_for_team.flat_map(&:violations)
            # We look at `all_packages` because we care about ALL inbound violations across all teams
            inbound_violations_by_package = all_packages.flat_map(&:violations).group_by(&:to_package_name)
            # Here we only look at packages_for_team because we only care about inbound violations onto packages for this team
            inbound_violations = packages_for_team.flat_map { |package| inbound_violations_by_package[package.name] || [] }

            PackwerkCheckerUsage::CHECKERS.each do |checker|
              direction = checker.direction
              case direction
              when PackwerkCheckerUsage::Direction::Outbound
                all_violations_of_type = outbound_violations.select { |v| v.type == checker.violation_type } 

                violation_count = packages_for_team.sum { |package| Metrics.file_count(package.violations.select{|v| v.type == checker.violation_type}) }
                tags = team_tags + [checker.violation_type_tag]
                all_metrics << GaugeMetric.for("by_team.violations.count", violation_count, tags)

                all_packages.group_by { |package| Private.package_owner(package) }.each do |other_team_name, other_teams_packages|
                  violations = outbound_violations.select{|v| other_teams_packages.map(&:name).include?(v.to_package_name) && v.type == checker.violation_type}
                  tags = team_tags + Metrics.tags_for_other_team(other_team_name) + [checker.violation_type_tag]
                  all_metrics << GaugeMetric.for("by_team.violations.per_team.count", Metrics.file_count(violations), tags)
                end
              when PackwerkCheckerUsage::Direction::Inbound
                all_violations_of_type = inbound_violations.select { |v| v.type == checker.violation_type } 

                violation_count = packages_for_team.sum { |package| Metrics.file_count(package.violations.select{|v| v.type == checker.violation_type}) }
                tags = team_tags + [checker.violation_type_tag]
                all_metrics << GaugeMetric.for("by_team.violations.count", violation_count, tags)

                all_packages.group_by { |package| Private.package_owner(package) }.each do |other_team_name, other_teams_packages|
                  violations = other_teams_packages.flat_map(&:violations).select{|v| packages_for_team.map(&:name).include?(v.to_package_name) && v.type == checker.violation_type}
                  tags = team_tags + Metrics.tags_for_other_team(other_team_name) + [checker.violation_type_tag]
                  all_metrics << GaugeMetric.for("by_team.violations.per_team.count", Metrics.file_count(violations), tags)
                end
              else
                T.absurd(direction)
              end
            end
          end

          all_metrics
        end
      end
    end
  end
end

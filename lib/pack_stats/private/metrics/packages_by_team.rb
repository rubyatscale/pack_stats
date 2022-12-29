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

          
          all_packages.group_by { |package| Private.package_owner(package) }.each do |team_name, packages_by_team|
            # We look at `all_packages` because we care about ALL inbound violations across all teams
            inbound_violations_by_package = all_packages.flat_map(&:violations).group_by(&:to_package_name)

            team_tags = Metrics.tags_for_team(team_name) + [app_level_tag]
            all_metrics << GaugeMetric.for('by_team.all_packages.count', packages_by_team.count, team_tags)
            all_metrics += Metrics::PackwerkCheckerUsage.get_checker_metrics('by_team', packages_by_team, team_tags)
            all_metrics += Metrics::PublicUsage.get_public_usage_metrics('by_team', packages_by_team, team_tags)
            #
            # VIOLATIONS (implicit dependencies)
            #
            outbound_violations = packages_by_team.flat_map(&:violations)
            # Here we only look at packages_by_team because we only care about inbound violations onto packages for this team
            inbound_violations = packages_by_team.flat_map { |package| inbound_violations_by_package[package.name] || [] }
            all_dependency_violations = (outbound_violations + inbound_violations).select(&:dependency?)
            all_privacy_violations = (outbound_violations + inbound_violations).select(&:privacy?)

            all_metrics << GaugeMetric.for('by_team.dependency_violations.count', Metrics.file_count(all_dependency_violations), team_tags)
            all_metrics << GaugeMetric.for('by_team.privacy_violations.count', Metrics.file_count(all_privacy_violations), team_tags)

            all_metrics << GaugeMetric.for('by_team.outbound_dependency_violations.count', Metrics.file_count(outbound_violations.select(&:dependency?)), team_tags)
            all_metrics << GaugeMetric.for('by_team.inbound_dependency_violations.count', Metrics.file_count(inbound_violations.select(&:dependency?)), team_tags)

            all_metrics << GaugeMetric.for('by_team.outbound_privacy_violations.count', Metrics.file_count(outbound_violations.select(&:privacy?)), team_tags)
            all_metrics << GaugeMetric.for('by_team.inbound_privacy_violations.count', Metrics.file_count(inbound_violations.select(&:privacy?)), team_tags)

            all_metrics << GaugeMetric.for('by_team.has_readme.count', packages_by_team.count { |package| Metrics.has_readme?(package) }, team_tags)

            grouped_outbound_violations = outbound_violations.group_by do |violation|
              to_package = ParsePackwerk.find(violation.to_package_name)
              if to_package.nil?
                raise StandardError, "Could not find matching package #{violation.to_package_name}"
              end

              Private.package_owner(to_package)
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
end

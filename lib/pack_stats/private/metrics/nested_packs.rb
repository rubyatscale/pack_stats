# typed: strict
# frozen_string_literal: true

module PackStats
  module Private
    module Metrics
      class NestedPacks
        extend T::Sig

        class PackGroup < T::Struct
          extend T::Sig

          const :name, String
          const :root, ParsePackwerk::Package
          const :members, T::Array[ParsePackwerk::Package]

          sig { params(packages: T::Array[ParsePackwerk::Package]).returns(T::Array[PackGroup]) }
          def self.all_from(packages)
            packs_by_group = {}

            packages.each do |package|
              # For a child pack, package.directory is `packs/fruits/apples` (i.e. the directory of the package.yml file).
              # The package.directory.dirname is therefore `packs/fruits`.
              # For a standalone pack, package.directory.dirname is `packs`
              # A pack with no parent is in a pack group of its own name
              root = ParsePackwerk.find(package.directory.dirname.to_s) || package
              # Mark the parent pack and child pack as being in the pack group of the parent
              packs_by_group[root.name] ||= { root: root, members: [] }
              packs_by_group[root.name][:members] << package
            end

            packs_by_group.map do |name, pack_data|
              PackGroup.new(
                name: name,
                root: pack_data[:root],
                members: pack_data[:members],
              )
            end
          end

          sig { returns(Integer) }
          def children_pack_count
            members.count do |package|
              package.name != root.name
            end
          end

          sig { returns(T::Boolean) }
          def has_parent?
            children_pack_count > 0
          end

          sig { returns(T::Array[ParsePackwerk::Violation]) }
          def cross_group_violations
            all_violations = members.flat_map do |member|
              ParsePackwerk::PackageTodo.for(member).violations
            end

            all_violations.select do |violation|
              !members.map(&:name).include?(violation.to_package_name)
            end
          end
        end

        sig do
          params(
            packages: T::Array[ParsePackwerk::Package],
            app_name: String
          ).returns(T::Array[GaugeMetric])
        end
        def self.get_nested_package_metrics(packages, app_name)
          all_metrics = []
          app_level_tag = Tag.for('app', app_name)
          package_tags = T.let([app_level_tag], T::Array[Tag])

          pack_groups = PackGroup.all_from(packages)
          all_pack_groups_count = pack_groups.count
          child_pack_count = pack_groups.sum(&:children_pack_count)
          parent_pack_count = pack_groups.count(&:has_parent?)
          all_cross_pack_group_violations = pack_groups.flat_map(&:cross_group_violations)

          all_metrics << GaugeMetric.for('all_pack_groups.count', all_pack_groups_count, package_tags)
          all_metrics << GaugeMetric.for('child_packs.count', child_pack_count, package_tags)
          all_metrics << GaugeMetric.for('parent_packs.count', parent_pack_count, package_tags)
          all_metrics << GaugeMetric.for('all_pack_groups.privacy_violations.count', Metrics.file_count(all_cross_pack_group_violations.select(&:privacy?)), package_tags)
          all_metrics << GaugeMetric.for('all_pack_groups.dependency_violations.count', Metrics.file_count(all_cross_pack_group_violations.select(&:dependency?)), package_tags)\

          packs_by_group = {}
          pack_groups.each do |pack_group|
            pack_group.members.each do |member|
              packs_by_group[member.name] = pack_group.name
            end
          end

          inbound_violations_by_pack_group = {}
          all_cross_pack_group_violations.group_by(&:to_package_name).each do |to_package_name, violations|
            violations.each do |violation|
              pack_group_for_violation = packs_by_group[violation.to_package_name]
              inbound_violations_by_pack_group[pack_group_for_violation] ||= []
              inbound_violations_by_pack_group[pack_group_for_violation] << violation
            end
          end

          pack_groups.each do |pack_group|
            tags = [
              *package_tags,
              Tag.for('pack_group', Metrics.humanized_package_name(pack_group.name)),
            ]

            outbound_dependency_violations = pack_group.cross_group_violations.select(&:dependency?)
            inbound_privacy_violations = inbound_violations_by_pack_group.fetch(pack_group.name, []).select(&:privacy?)
            all_metrics << GaugeMetric.for('by_pack_group.outbound_dependency_violations.count', Metrics.file_count(outbound_dependency_violations), tags)
            all_metrics << GaugeMetric.for('by_pack_group.inbound_privacy_violations.count', Metrics.file_count(inbound_privacy_violations), tags)
          end

          pack_groups.each do |from_pack_group|
            violations_by_to_pack_group = from_pack_group.cross_group_violations.group_by do |violation|
              packs_by_group[violation.to_package_name]
            end
            violations_by_to_pack_group.each do |to_pack_group_name, violations|
              tags = [
                *package_tags,
                Tag.for('pack_group', Metrics.humanized_package_name(from_pack_group.name)),
                Tag.for('to_pack_group', Metrics.humanized_package_name(to_pack_group_name)),
              ]

              all_metrics << GaugeMetric.for('by_pack_group.outbound_dependency_violations.per_pack_group.count', Metrics.file_count(violations.select(&:dependency?)), tags)
              all_metrics << GaugeMetric.for('by_pack_group.outbound_privacy_violations.per_pack_group.count', Metrics.file_count(violations.select(&:privacy?)), tags)
            end
          end

          all_metrics
        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

module ModularizationStatistics
  module Private
    module Metrics
      class ProtectionUsage
        extend T::Sig

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_protections_metrics(prefix, packages, package_tags)
          # These should look at native packwerk...?
          # Perhaps two implementations:
          # If the package has a protections key, use the old implementation.
          # If it doesn't, use the "new" implementation, which checks `enforce_privacy` and `enforce_dependencies`, `.pack_rubocop.yml`,
          # `metadata.enforce_privacy_strictly: true, metadata.enforce_dependencies_strictly: true`
          protected_packages = packages.map { |p| PackageProtections::ProtectedPackage.from(p) }
          # [
          #   'prevent_this_package_from_violating_its_stated_dependencies',
          #   'prevent_other_packages_from_using_this_packages_internals',
          #   'prevent_this_package_from_exposing_an_untyped_api',
          #   'prevent_this_package_from_creating_other_namespaces',
          #   'prevent_other_packages_from_using_this_package_without_explicit_visibility',
          #   'prevent_this_package_from_exposing_instance_method_public_apis',
          #   'prevent_this_package_from_exposing_undocumented_public_apis'
          # ]
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
      end
    end
  end
end

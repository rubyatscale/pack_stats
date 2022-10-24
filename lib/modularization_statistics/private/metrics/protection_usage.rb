# typed: strict
# frozen_string_literal: true

module ModularizationStatistics
  module Private
    module Metrics
      class ProtectionUsage
        extend T::Sig

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_protections_metrics(prefix, packages, package_tags)
          protected_packages = packages.map { |p| PackageProtections::ProtectedPackage.from(p) }
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
              count_of_packages = protected_packages.count do |p|
                #
                # This is temporarily in place until we migrate off of `package_protections` in favor of `rubocop-packs`.
                # At that point, we want to delete this branch and instead it we'd probably have two separate branches.
                # One branch would look at `enforce_x` and `metadata.strictly_enforce_x`.
                # The other branch would look at `.pack_rubocop.yml`.
                # Later on, we could generalize this so that it automatically incorporates new cops from `rubocop-packs`,
                # or even new packwerk plugins.
                #
                # Regardless, we'll want to keep the way we are naming these behaviors for now to preserve historical trends in the data.
                #
                if p.metadata['protections']
                  p.violation_behavior_for(protection.identifier) == violation_behavior
                else
                  case violation_behavior
                  when PackageProtections::ViolationBehavior::FailOnAny
                    # There is not yet an implementation for `FailOnAny` for systems that don't use package protections
                    false
                  when PackageProtections::ViolationBehavior::FailNever
                    if protection.identifier == 'prevent_this_package_from_violating_its_stated_dependencies'
                      !p.original_package.enforces_dependencies?
                    elsif protection.identifier == 'prevent_other_packages_from_using_this_packages_internals'
                      !p.original_package.enforces_privacy?
                    else
                      # This is not applicable if you're not using package protections
                      true
                    end
                  when PackageProtections::ViolationBehavior::FailOnNew
                    if protection.identifier == 'prevent_this_package_from_violating_its_stated_dependencies'
                      p.original_package.enforces_dependencies?
                    elsif protection.identifier == 'prevent_other_packages_from_using_this_packages_internals'
                      p.original_package.enforces_privacy?
                    else
                      # This is not applicable if you're not using package protections
                      false
                    end
                  else
                    T.absurd(violation_behavior)
                  end
                end
              end
              GaugeMetric.for(metric_name, count_of_packages, package_tags)
            end
          end
        end
      end
    end
  end
end

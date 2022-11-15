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
                # One branch would look at `enforce_x` and `metadata.enforce_x_strictly`.
                # The other branch would look at `.pack_rubocop.yml`.
                # Later on, we could generalize this so that it automatically incorporates new cops from `rubocop-packs`,
                # or even new packwerk plugins.
                #
                # Regardless, we'll want to keep the way we are naming these behaviors for now to preserve historical trends in the data.
                #
                if p.metadata['protections']
                  p.violation_behavior_for(protection.identifier) == violation_behavior
                else
                  should_count_package?(p.original_package, protection, violation_behavior)
                end
              end
              GaugeMetric.for(metric_name, count_of_packages, package_tags)
            end
          end
        end

        #
        # Later, when we remove package protections, we can make this simpler by iterating over
        # packwerk checkers and rubocop packs specifically. That would let us use a common, simple
        # strategy to get metrics for both of them. For the first iteration, we'll want to continue
        # to map the old names of things to the "protection" names. After that, I think we will want to
        # extract that mapping into a tool that transforms the metrics that can be optionally turned off
        # so that we can see metrics that are more closely connected to the new API.
        # e.g. instead of `all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_on_any.count`, we'd see
        # e.g. instead of `all_packages.checkers.enforce_dependencies.strict.count`, we'd see
        # e.g. instead of `all_packages.prevent_this_package_from_creating_other_namespaces.fail_on_new.count`, we'd see
        # e.g. instead of `all_packages.cops.packs_namespaceconvention.true.count`, we'd see
        # 
        sig do
          params(
            package: ParsePackwerk::Package,
            protection: PackageProtections::ProtectionInterface,
            violation_behavior: PackageProtections::ViolationBehavior
          ).returns(T::Boolean)
        end
        def self.should_count_package?(package, protection, violation_behavior)
          if protection.identifier == 'prevent_this_package_from_violating_its_stated_dependencies'
            strict_mode = package.metadata['enforce_dependencies_strictly']
            enabled = package.enforces_dependencies?

            case violation_behavior
            when PackageProtections::ViolationBehavior::FailOnAny
              !!strict_mode
            when PackageProtections::ViolationBehavior::FailNever
              !enabled
            when PackageProtections::ViolationBehavior::FailOnNew
              enabled && !strict_mode
            else
              T.absurd(violation_behavior)
            end
          elsif protection.identifier == 'prevent_other_packages_from_using_this_packages_internals'
            strict_mode = package.metadata['enforce_privacy_strictly']
            enabled = package.enforces_privacy?

            case violation_behavior
            when PackageProtections::ViolationBehavior::FailOnAny
              !!strict_mode
            when PackageProtections::ViolationBehavior::FailNever
              !enabled
            when PackageProtections::ViolationBehavior::FailOnNew
              enabled && !strict_mode
            else
              T.absurd(violation_behavior)
            end
          else
            # Otherwise, we're in a rubocop case
            rubocop_yml_file = package.directory.join(RuboCop::Packs::PACK_LEVEL_RUBOCOP_YML)
            return false if !rubocop_yml_file.exist?
            rubocop_yml = YAML.load_file(rubocop_yml_file)
            protection = T.cast(protection, PackageProtections::RubocopProtectionInterface)
            # We will likely want a rubocop-packs API for this, to be able to ask if a cop is enabled for a pack.
            # It's possible we will want to allow these to be enabled at the top-level `.rubocop.yml`,
            # in which case we wouldn't get the right metrics with this approach. However, we can also accept
            # that as a current limitation.
            cop_map = {
              'PackageProtections/TypedPublicApi' => 'Packs/TypedPublicApis',
              'PackageProtections/NamespacedUnderPackageName' => 'Packs/RootNamespaceIsPackName',
              'PackageProtections/OnlyClassMethods' => 'Packs/ClassMethodsAsPublicApis',
              'PackageProtections/RequireDocumentedPublicApis' => 'Packs/DocumentedPublicApis',
            }
            # We want to use the cop names from `rubocop-packs`. Eventually, we'll just literate over these
            # cop names directly, or ask `rubocop-packs` for the list of cops to care about.
            cop_config = rubocop_yml[cop_map[protection.cop_name]]
            return false if cop_config.nil?
            enabled = cop_config['Enabled']
            strict_mode = cop_config['FailureMode'] == 'strict'

            case violation_behavior
            when PackageProtections::ViolationBehavior::FailOnAny
              !!strict_mode
            when PackageProtections::ViolationBehavior::FailNever
              !enabled
            when PackageProtections::ViolationBehavior::FailOnNew
              enabled && !strict_mode
            else
              T.absurd(violation_behavior)
            end
          end
        end
      end
    end
  end
end

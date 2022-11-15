# typed: strict
# frozen_string_literal: true

require 'rubocop-packs'

module ModularizationStatistics
  module Private
    module Metrics
      class ProtectionUsage
        extend T::Sig
        
        # Later, we might find a way we can get this directly from `packwerk`
        class PackwerkChecker < T::Struct
          const :setting, String
          const :strict_mode, String
          # Later, we might convert to legacy metric names later so new clients get more sensible metric names
          # That is, we might want to see metrics that are more closely connected to the new API.
          # e.g. instead of `all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_on_any.count`, we'd see `all_packages.checkers.enforce_dependencies.strict.count`
          # e.g. instead of `all_packages.prevent_this_package_from_creating_other_namespaces.fail_on_new.count`, `all_packages.cops.packs_namespaceconvention.true.count`
          const :legacy_metric_name, String
        end

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_protections_metrics(prefix, packages, package_tags)
          metrics = T.let([], T::Array[GaugeMetric])

          # Packwerk Checkers
          checkers = [
            PackwerkChecker.new(setting: 'enforce_dependencies', strict_mode: 'enforce_dependencies_strictly', legacy_metric_name: 'prevent_this_package_from_violating_its_stated_dependencies'),
            PackwerkChecker.new(setting: 'enforce_privacy', strict_mode: 'enforce_privacy_strictly', legacy_metric_name: 'prevent_other_packages_from_using_this_packages_internals')
          ]

          checkers.each do |checker|
            ['no', 'fail_the_build_if_new_instances_appear', 'fail_the_build_on_any_instances'].each do |violation_behavior|
              count_of_packages = ParsePackwerk.all.count do |package|
                strict_mode = package.metadata[checker.strict_mode]
                enabled = YAML.load_file(package.yml)[checker.setting]
                case violation_behavior
                when 'fail_the_build_on_any_instances'
                  !!strict_mode
                when 'no'
                  !enabled
                when 'fail_the_build_if_new_instances_appear'
                  enabled && !strict_mode
                end
              end

              metric_name = "#{prefix}.#{checker.legacy_metric_name}.#{violation_behavior}.count"
              metrics << GaugeMetric.for(metric_name, count_of_packages, package_tags)
            end
          end
          
          # Rubocops
          rubocops = {
            'Packs/ClassMethodsAsPublicApis' => 'prevent_this_package_from_exposing_an_untyped_api',
            'Packs/RootNamespaceIsPackName' => 'prevent_this_package_from_creating_other_namespaces',
            'Packs/TypedPublicApis' => 'prevent_this_package_from_exposing_an_untyped_api',
            'Packs/DocumentedPublicApis' => 'prevent_this_package_from_exposing_undocumented_public_apis',
          }
          
          rubocops.each do |cop_name, legacy_name|
            ['no', 'fail_the_build_if_new_instances_appear', 'fail_the_build_on_any_instances'].each do |violation_behavior|
              count_of_packages = ParsePackwerk.all.count do |package|
                # We will likely want a rubocop-packs API for this, to be able to ask if a cop is enabled for a pack.
                # It's possible we will want to allow these to be enabled at the top-level `.rubocop.yml`,
                # in which case we wouldn't get the right metrics with this approach. However, we can also accept
                # that as a current limitation.
                rubocop_yml_file = package.directory.join(RuboCop::Packs::PACK_LEVEL_RUBOCOP_YML)
                next false if !rubocop_yml_file.exist?
                rubocop_yml = YAML.load_file(rubocop_yml_file)
                cop_config = rubocop_yml[cop_name]

                strict_mode = cop_config && cop_config['FailureMode'] == 'strict'
                enabled = cop_config && cop_config['Enabled']
                case violation_behavior
                when 'fail_the_build_on_any_instances'
                  !!strict_mode
                when 'no'
                  !enabled
                when 'fail_the_build_if_new_instances_appear'
                  enabled && !strict_mode
                end
              end

              metric_name = "#{prefix}.#{legacy_name}.#{violation_behavior}.count"
              metrics << GaugeMetric.for(metric_name, count_of_packages, package_tags)
            end
          end

          metrics
        end
      end
    end
  end
end

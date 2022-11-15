# typed: strict
# frozen_string_literal: true

module ModularizationStatistics
  module Private
    module Metrics
      class RubocopUsage
        extend T::Sig

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_metrics(prefix, packages, package_tags)
          [
            *get_rubocop_exclusions(prefix, packages, package_tags),
            *get_rubocop_usage_metrics(prefix, packages, package_tags)
          ]
        end

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_rubocop_usage_metrics(prefix, packages, package_tags)
          # Rubocops
          metrics = T.let([], T::Array[GaugeMetric])
          
          rubocop_legacy_metric_map.each do |cop_name, legacy_name|
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

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_rubocop_exclusions(prefix, packages, package_tags)
          rubocop_legacy_metric_map.flat_map do |cop_name, legacy_name|
            metric_name = "#{prefix}.#{legacy_name}.rubocop_exclusions.count"
            all_exclusions_count = ParsePackwerk.all.sum { |package| exclude_count_for_package_and_protection(package, cop_name)}
            GaugeMetric.for(metric_name, all_exclusions_count, package_tags)
          end
        end

        # TODO: `rubocop-packs` may want to expose API for this
        sig { params(package: ParsePackwerk::Package, cop_name: String).returns(Integer) }
        def self.exclude_count_for_package_and_protection(package, cop_name)
          if package.name == ParsePackwerk::ROOT_PACKAGE_NAME
            rubocop_todo = package.directory.join('.rubocop_todo.yml')
          else
            rubocop_todo = package.directory.join(RuboCop::Packs::PACK_LEVEL_RUBOCOP_TODO_YML)
          end

          if rubocop_todo.exist?
            loaded_rubocop_todo = YAML.load_file(rubocop_todo)
            cop_config = loaded_rubocop_todo.fetch(cop_name, {})
            cop_config.fetch('Exclude', []).count
          else
            0
          end
        end

        sig { returns(T::Hash[String, String])}
        def self.rubocop_legacy_metric_map
          {
            'Packs/ClassMethodsAsPublicApis' => 'prevent_this_package_from_exposing_an_untyped_api',
            'Packs/RootNamespaceIsPackName' => 'prevent_this_package_from_creating_other_namespaces',
            'Packs/TypedPublicApis' => 'prevent_this_package_from_exposing_an_untyped_api',
            'Packs/DocumentedPublicApis' => 'prevent_this_package_from_exposing_undocumented_public_apis',
          }
        end
      end
    end
  end
end

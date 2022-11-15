# typed: strict
# frozen_string_literal: true

module ModularizationStatistics
  module Private
    module Metrics
      class RubocopProtectionsExclusions
        extend T::Sig

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_rubocop_exclusions(prefix, packages, package_tags)
          # TODO: Pull rubocop stuff from lib/modularization_statistics/private/metrics/protection_usage.rb into this file
          # And change protection_usage.rb to be packwerk_checker_usage.rb
          rubocops = {
            'Packs/ClassMethodsAsPublicApis' => 'prevent_this_package_from_exposing_an_untyped_api',
            'Packs/RootNamespaceIsPackName' => 'prevent_this_package_from_creating_other_namespaces',
            'Packs/TypedPublicApis' => 'prevent_this_package_from_exposing_an_untyped_api',
            'Packs/DocumentedPublicApis' => 'prevent_this_package_from_exposing_undocumented_public_apis',
          }
          rubocops.flat_map do |cop_name, legacy_name|
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
      end
    end
  end
end

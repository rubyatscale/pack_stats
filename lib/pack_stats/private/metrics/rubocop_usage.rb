# typed: strict
# frozen_string_literal: true

module PackStats
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
          metrics = T.let([], T::Array[GaugeMetric])
          
          rubocops.each do |cop_name|
            ['false', 'true', 'strict'].each do |enabled_mode|
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
                case enabled_mode
                when 'false'
                  !enabled
                when 'true'
                  enabled && !strict_mode
                when 'strict'
                  !!strict_mode
                end
              end

              metric_name = "#{prefix}.rubocops.#{to_tag_name(cop_name)}.#{enabled_mode}.count"
              metrics << GaugeMetric.for(metric_name, count_of_packages, package_tags)
            end
          end

          metrics
        end

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_rubocop_exclusions(prefix, packages, package_tags)
          rubocops.flat_map do |cop_name|
            metric_name = "#{prefix}.rubocops.#{to_tag_name(cop_name)}.exclusions.count"
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

        sig { returns(T::Array[String])}
        def self.rubocops
          [
            'Packs/ClassMethodsAsPublicApis',
            'Packs/RootNamespaceIsPackName',
            'Packs/TypedPublicApis',
            'Packs/DocumentedPublicApis',
          ]
        end

        sig { params(cop_name: String).returns(String) }
        def self.to_tag_name(cop_name)
          cop_name.gsub('/', '_').downcase
        end
      end
    end
  end
end

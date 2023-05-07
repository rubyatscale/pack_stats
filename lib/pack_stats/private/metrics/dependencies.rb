# typed: strict
# frozen_string_literal: true

module PackStats
  module Private
    module Metrics
      class Dependencies
        extend T::Sig

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], app_name: String).returns(T::Array[GaugeMetric]) }
        def self.get_metrics(prefix, packages, app_name)
          all_metrics = T.let([], T::Array[GaugeMetric])
          inbound_explicit_dependency_by_package = {}
          packages.each do |package|
            package.dependencies.each do |explicit_dependency|
              inbound_explicit_dependency_by_package[explicit_dependency] ||= []
              inbound_explicit_dependency_by_package[explicit_dependency] << package.name
            end
          end

          packages.each do |package| # rubocop:disable Style/CombinableLoops
            package_tags = Metrics.tags_for_package(package, app_name)

            #
            # EXPLICIT DEPENDENCIES
            #
            package.dependencies.each do |explicit_dependency|
              to_package = ParsePackwerk.find(explicit_dependency)
              if to_package.nil?
                raise StandardError, "Could not find matching package #{explicit_dependency}"
              end

              owner = Private.package_owner(to_package)
              tags = package_tags + [Tag.for('other_package', Metrics.humanized_package_name(explicit_dependency))] + Metrics.tags_for_other_team(owner)
              all_metrics << GaugeMetric.for('by_package.dependencies.by_other_package.count', 1, tags)
            end

            all_metrics << GaugeMetric.for('by_package.dependencies.count', package.dependencies.count, package_tags)
            all_metrics << GaugeMetric.for('by_package.depended_on.count', inbound_explicit_dependency_by_package[package.name]&.count || 0, package_tags)
          end

          all_metrics
        end
      end
    end
  end
end

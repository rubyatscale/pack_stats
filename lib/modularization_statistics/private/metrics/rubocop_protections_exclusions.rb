# typed: strict
# frozen_string_literal: true

module ModularizationStatistics
  module Private
    module Metrics
      # TODO:
      # Should we create API in `rubocop-packs` for some of this?
      class RubocopProtectionsExclusions
        extend T::Sig

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_rubocop_exclusions(prefix, packages, package_tags)
          protected_packages = packages.map { |p| PackageProtections::ProtectedPackage.from(p) }

          rubocop_based_package_protections = T.cast(PackageProtections.all.select { |p| p.is_a?(PackageProtections::RubocopProtectionInterface) }, T::Array[PackageProtections::RubocopProtectionInterface])
          rubocop_based_package_protections.flat_map do |rubocop_based_package_protection|
            metric_name = "#{prefix}.#{rubocop_based_package_protection.identifier}.rubocop_exclusions.count"
            all_exclusions_count = ParsePackwerk.all.sum { |package| exclude_count_for_package_and_protection(package, rubocop_based_package_protection)}
            GaugeMetric.for(metric_name, all_exclusions_count, package_tags)
          end
        end

        sig { params(package: ParsePackwerk::Package, protection: PackageProtections::RubocopProtectionInterface).returns(Integer) }
        def self.exclude_count_for_package_and_protection(package, protection)
          rubocop_todo = package.directory.join('.rubocop_todo.yml')
          if rubocop_todo.exist?
            loaded_rubocop_todo = YAML.load_file(rubocop_todo)
            cop_config = loaded_rubocop_todo.fetch(protection.cop_name, {})
            cop_config.fetch('Exclude', []).count
          else
            0
          end
        end
      end
    end
  end
end

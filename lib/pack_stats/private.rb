# typed: strict

module PackStats
  module Private
    extend T::Sig

    METRIC_REPLACEMENTS = T.let({
      # enforce_dependencies
      'packwerk_checkers.enforce_dependencies.false' => 'prevent_this_package_from_violating_its_stated_dependencies.no',
      'packwerk_checkers.enforce_dependencies.true' => 'prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_if_new_instances_appear',
      'packwerk_checkers.enforce_dependencies.strict' => 'prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_on_any_instances',
      # enforce_privacy
      'packwerk_checkers.enforce_privacy.false' => 'prevent_other_packages_from_using_this_packages_internals.no',
      'packwerk_checkers.enforce_privacy.true' => 'prevent_other_packages_from_using_this_packages_internals.fail_the_build_if_new_instances_appear',
      'packwerk_checkers.enforce_privacy.strict' => 'prevent_other_packages_from_using_this_packages_internals.fail_the_build_on_any_instances',
      # Packs/TypedPublicApis
      'rubocops.packs_typedpublicapis.false' => 'prevent_this_package_from_exposing_an_untyped_api.no',
      'rubocops.packs_typedpublicapis.true' => 'prevent_this_package_from_exposing_an_untyped_api.fail_the_build_if_new_instances_appear',
      'rubocops.packs_typedpublicapis.strict' => 'prevent_this_package_from_exposing_an_untyped_api.fail_the_build_on_any_instances',
      'rubocops.packs_typedpublicapis.exclusions' => 'prevent_this_package_from_exposing_an_untyped_api.rubocop_exclusions',
      # Packs/RootNamespaceIsPackName
      'rubocops.packs_rootnamespaceispackname.false' => 'prevent_this_package_from_creating_other_namespaces.no',
      'rubocops.packs_rootnamespaceispackname.true' => 'prevent_this_package_from_creating_other_namespaces.fail_the_build_if_new_instances_appear',
      'rubocops.packs_rootnamespaceispackname.strict' => 'prevent_this_package_from_creating_other_namespaces.fail_the_build_on_any_instances',
      'rubocops.packs_rootnamespaceispackname.exclusions' => 'prevent_this_package_from_creating_other_namespaces.rubocop_exclusions',
      # Packs/ClassMethodsAsPublicApis
      'rubocops.packs_classmethodsaspublicapis.false' => 'prevent_this_package_from_exposing_instance_method_public_apis.no',
      'rubocops.packs_classmethodsaspublicapis.true' => 'prevent_this_package_from_exposing_instance_method_public_apis.fail_the_build_if_new_instances_appear',
      'rubocops.packs_classmethodsaspublicapis.strict' => 'prevent_this_package_from_exposing_instance_method_public_apis.fail_the_build_on_any_instances',
      'rubocops.packs_classmethodsaspublicapis.exclusions' => 'prevent_this_package_from_exposing_instance_method_public_apis.rubocop_exclusions',
      # Packs/DocumentedPublicApis
      'rubocops.packs_documentedpublicapis.false' => 'prevent_this_package_from_exposing_undocumented_public_apis.no',
      'rubocops.packs_documentedpublicapis.true' => 'prevent_this_package_from_exposing_undocumented_public_apis.fail_the_build_if_new_instances_appear',
      'rubocops.packs_documentedpublicapis.strict' => 'prevent_this_package_from_exposing_undocumented_public_apis.fail_the_build_on_any_instances',
      'rubocops.packs_documentedpublicapis.exclusions' => 'prevent_this_package_from_exposing_undocumented_public_apis.rubocop_exclusions',
    }, T::Hash[String, String])

    sig { params(metrics: T::Array[GaugeMetric]).returns(T::Array[GaugeMetric]) }
    def self.convert_metrics_to_legacy(metrics)
      metrics.map do |metric|
        new_metric = metric
        METRIC_REPLACEMENTS.each do |current_name, legacy_name|
          new_metric = new_metric.with(
            name: new_metric.name.gsub(current_name, legacy_name)
          )
        end

        new_metric
      end
    end

    sig { params(package: ParsePackwerk::Package).returns(T.nilable(String) )}
    def self.package_owner(package)
      pack = Packs.find(package.name)
      return nil if pack.nil?
      CodeOwnership.for_package(pack)&.name
    end
  end

  private_constant :Private
end

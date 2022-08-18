# frozen_string_literal: true

module ModularizationStatistics # rubocop:disable RSpec/DescribedClassModuleWrapping
  RSpec.describe ModularizationStatistics do
    before do
      ParsePackwerk.bust_cache!
    end

    describe 'ModularizationStatistics.report_to_datadog!' do
      let(:report_to_datadog) do
        ModularizationStatistics.report_to_datadog!(
          app_name: 'MyApp',
          source_code_pathnames: Pathname.glob('**/**.rb'),
          datadog_client: datadog_client,
          report_time: report_time
        )
      end

      let(:datadog_client) { sorbet_double(Dogapi::Client) }
      let(:report_time) { Time.now } # rubocop:disable Rails/TimeZone

      let(:expected_metric) do
        GaugeMetric.for('some_metric', 11, Tags.for(['mykey:myvalue', 'myotherkey:myothervalue']))
      end

      before do
        allow(ModularizationStatistics).to receive(:get_metrics).and_return([expected_metric])
      end

      it 'emits to datadog' do
        expect(datadog_client).to receive(:batch_metrics).and_yield # rubocop:disable RSpec/MessageSpies
        expect(datadog_client).to receive(:emit_points).with( # rubocop:disable RSpec/MessageSpies
          'modularization.some_metric',
          [[report_time, 11]],
          type: 'gauge',
          tags: ['mykey:myvalue', 'myotherkey:myothervalue']
        )
        report_to_datadog
      end
    end

    describe 'ModularizationStatistics.get_metrics' do
      let(:subject) do
        ModularizationStatistics.get_metrics(
          app_name: 'MyApp',
          source_code_pathnames: Pathname.glob('**/**.rb'),
          componentized_source_code_locations: [Pathname.new('components')],
          packaged_source_code_locations: [Pathname.new('packs')]
        )
      end
      let(:metrics) { subject }

      before do
        CodeTeams.bust_caches!
        CodeOwnership.bust_caches!
      end

      context 'in empty app' do
        before do
          write_file('empty_file.rb')
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.totals', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.totals', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.totals', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.no.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.no.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.no.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.no.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.all_files.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.public_files.count', 0, Tags.for(['app:MyApp']))
        end
      end

      context 'in app with a simple package owned by one team' do
        include_context 'only one team'

        before do
          write_file('empty_file.rb')
          write_file('packs/only_package/app/some_package_file.rb')
          write_file('packs/only_package/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/only_package/spec/some_package_file_spec.rb')
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Some team', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 2, Tags.for(['team:Some team', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 3, Tags.for(['team:Some team', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.totals', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.totals', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.totals', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.all_files.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.public_files.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 0, Tags.for(['app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_files.count', 2, Tags.for(['app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.public_files.count', 0, Tags.for(['app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.using_public_directory.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.all_files.count', 2, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.public_files.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
        end
      end

      context 'in app with two packages owned by different teams' do
        include_context 'team names are based off of file names'
        before do
          write_file('empty_file.rb')
          write_file('packs/package_2/app/some_package_file.rb')
          write_file('packs/package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_2/spec/some_package_file_spec.rb')
          write_file('packs/package_1/app/some_package_file.rb')
          write_file('packs/package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_1/spec/some_package_file_spec.rb')
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 2, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 2, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 2, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 2, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.totals', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.totals', 4, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.totals', 5, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
        end

        it 'emits metrics about use of public directory' do
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.all_files.count', 4, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.public_files.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_files.count', 4, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.public_files.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.using_public_directory.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.all_files.count', 2, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.public_files.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.using_public_directory.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.all_files.count', 2, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.public_files.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
        end
      end

      context 'in app with one root and 2 nonroot packages with dependency violations' do
        include_context 'team names are based off of file names'

        before do
          write_file('deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/package_2:
              "UndeclaredConstant1":
                violations:
                - dependency
                files:
                - some_file.rb
              "UndeclaredConstant2":
                violations:
                - dependency
                files:
                - some_file.rb
          CONTENTS

          write_file('config/teams/art/artists.yml', <<~CONTENTS)
            name: Artists
          CONTENTS

          write_file('config/teams/food/chefs.yml', <<~CONTENTS)
            name: Chefs
          CONTENTS

          write_file('package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: false
            dependencies:
              - packs/package_1
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_new
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('empty_file_to_keep_directory.rb')
          write_file('packs/package_2/deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/package_1:
              "UndeclaredConstant3":
                violations:
                - dependency
                files:
                - some_file.rb
              "UndeclaredConstant4":
                violations:
                - dependency
                files:
                - some_file.rb
            ".":
              "UndeclaredConstant4":
                violations:
                - dependency
                files:
                - some_file.rb
          CONTENTS

          write_file('packs/package_2/app/some_package_file.rb')
          write_file('packs/package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: false
            metadata:
              owner: Chefs
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_new
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_2/spec/some_package_file_spec.rb')
          write_file('packs/package_1/app/some_package_file.rb')
          write_file('packs/package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: false
            dependencies:
              - packs/package_2
            metadata:
              owner: Artists
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_new
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_1/spec/some_package_file_spec.rb')
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 2, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 2, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 2, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 2, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.totals', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.totals', 4, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.totals', 5, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 5, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_if_new_instances_appear.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 5, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 3, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 2, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 2, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:packs/package_1', 'to_team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:packs/package_1', 'to_team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 2, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 2, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 3, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 2, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 1, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 2, Tags.for(['package:root', 'app:MyApp', 'team:Unknown', 'to_package:packs/package_2', 'to_team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 0, Tags.for(['package:root', 'app:MyApp', 'team:Unknown', 'to_package:packs/package_2', 'to_team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.per_package.count', 1, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists', 'to_package:packs/package_2', 'to_team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 1, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 1, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.per_package.count', 1, Tags.for(['package:root', 'app:MyApp', 'team:Unknown', 'to_package:packs/package_1', 'to_team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 1, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
        end

        it 'emits team based package metrics' do
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_packages.count', 1, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.dependency_violations.count', 5, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.privacy_violations.count', 0, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_dependency_violations.count', 3, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.inbound_dependency_violations.count', 2, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_privacy_violations.count', 0, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.inbound_privacy_violations.count', 0, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_dependency_violations.per_team.count', 2, Tags.for(['team:Chefs', 'app:MyApp', 'to_team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_privacy_violations.per_team.count', 0, Tags.for(['team:Chefs', 'app:MyApp', 'to_team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_dependency_violations.per_team.count', 1, Tags.for(['team:Chefs', 'app:MyApp', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_privacy_violations.per_team.count', 0, Tags.for(['team:Chefs', 'app:MyApp', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_packages.count', 1, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.dependency_violations.count', 2, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.privacy_violations.count', 0, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_dependency_violations.count', 0, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.inbound_dependency_violations.count', 2, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_privacy_violations.count', 0, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.inbound_privacy_violations.count', 0, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_packages.count', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.dependency_violations.count', 3, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.privacy_violations.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_dependency_violations.count', 2, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.inbound_dependency_violations.count', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_privacy_violations.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.inbound_privacy_violations.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_dependency_violations.per_team.count', 2, Tags.for(['team:Unknown', 'app:MyApp', 'to_team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 0, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 0, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
        end
      end

      context 'in app with one root and 2 nonroot packages with privacy and dependency violations, and also components' do
        include_context 'team names are based off of file names'

        before do
          write_file('deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/package_2:
              "UndeclaredConstant1":
                violations:
                - dependency
                files:
                - some_file.rb
              "UndeclaredConstant2":
                violations:
                - dependency
                files:
                - some_file.rb
              "MyPrivateConstant2":
                violations:
                - privacy
                files:
                - some_file.rb
          CONTENTS

          write_file('app/unpackaged_files/team_1_file.rb')
          write_file('app/unpackaged_files/team_2_file.rb')
          write_file('package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: false
            dependencies:
              - packs/package_1
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_new
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('empty_file_to_keep_directory.rb')
          write_file('packs/package_2/deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/package_1:
              "UndeclaredConstant3":
                violations:
                - dependency
                files:
                - some_file.rb
              "UndeclaredConstant4":
                violations:
                - dependency
                files:
                - some_file.rb
              "MyPrivateConstant1":
                violations:
                - dependency
                - privacy
                files:
                - some_file.rb
            ".":
              "UndeclaredConstant4":
                violations:
                - dependency
                files:
                - some_file.rb
          CONTENTS

          write_file('packs/package_2/app/some_package_file.rb')
          write_file('packs/package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: true
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_new
                prevent_other_packages_from_using_this_packages_internals: fail_on_new
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_2/spec/some_package_file_spec.rb')
          write_file('packs/package_1/deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/package_2:
              "MyPrivateConstant2":
                violations:
                - privacy
                files:
                - some_file.rb
          CONTENTS

          write_file('packs/package_1/app/some_package_file.rb')
          write_file('packs/package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: true
            dependencies:
              - packs/package_2
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_new
                prevent_other_packages_from_using_this_packages_internals: fail_on_new
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_1/spec/some_package_file_spec.rb')
          write_file('components/my_component_2/spec/my_file_spec.rb')
          write_file('components/my_component_2/lib/my_component_2/my_file.rb')
          write_file('components/my_component_2/lib/my_component_2.rb')
          write_file('components/my_component_3/spec/my_file_spec.rb')
          write_file('components/my_component_3/lib/my_component_3/my_file.rb')
          write_file('components/my_component_3/lib/my_component_3.rb')
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 3, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 2, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 6, Tags.for(['team:Team 2', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 2, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 3, Tags.for(['team:Team 1', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.by_team', 3, Tags.for(['team:Team 3', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.by_team', 0, Tags.for(['team:Team 3', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.by_team', 3, Tags.for(['team:Team 3', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('component_files.totals', 6, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.totals', 4, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.totals', 13, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 6, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_if_new_instances_appear.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_if_new_instances_appear.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_if_new_instances_appear.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.fail_the_build_on_any_instances.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 6, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 3, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 4, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 2, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 2, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 3, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:packs/package_1', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:packs/package_1', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 3, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 2, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 3, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 0, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_2', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_2', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 3, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 1, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 2, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 1, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 1, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 2, Tags.for(['package:root', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_2', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 1, Tags.for(['package:root', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_2', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.per_package.count', 1, Tags.for(['package:root', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_1', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 1, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 0, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.per_package.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_2', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_2', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 1, Tags.for(['package:packs/package_2', 'team:Unknown', 'app:MyApp']))
        end
      end

      context 'in an app with a protected package' do
        include_context 'only one team'
        before do
          write_file('packs/package_2/app/public/untyped_file.rb', <<~CONTENTS)
            # typed: false
          CONTENTS

          write_file('packs/package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: true
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_new
                prevent_other_packages_from_using_this_packages_internals: fail_on_new
                prevent_this_package_from_exposing_an_untyped_api: fail_on_new
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_3/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: true
            metadata:
              other_stuff: is_irrelevant
              protections:
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_on_any
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: true
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_on_any
                prevent_other_packages_from_using_this_packages_internals: fail_on_any
                prevent_this_package_from_exposing_an_untyped_api: fail_on_any
                prevent_this_package_from_creating_other_namespaces: fail_on_any
          CONTENTS
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('component_files.totals', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.totals', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.totals', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_on_any_instances.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_violating_its_stated_dependencies.fail_the_build_if_new_instances_appear.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_on_any_instances.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_other_packages_from_using_this_packages_internals.fail_the_build_if_new_instances_appear.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_on_any_instances.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_exposing_an_untyped_api.fail_the_build_if_new_instances_appear.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.prevent_this_package_from_creating_other_namespaces.fail_the_build_on_any_instances.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_explicit_dependencies.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
        end
      end

      context 'in an app with mixed usage of public directories' do
        before do
          write_file('config/teams/art/artists.yml', <<~CONTENTS)
            name: Artists
          CONTENTS

          write_file('config/teams/food/chefs.yml', <<~CONTENTS)
            name: Chefs
          CONTENTS

          write_file('empty_file.rb')
          write_file('package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/artists_package_1/app/public/some_subdir/some_public_api_1.rb')
          write_file('packs/artists_package_1/app/public/some_subdir/some_public_api_2.rb')
          write_file('packs/artists_package_1/app/some_package_file.rb')
          write_file('packs/artists_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/chefs_package_2/app/some_package_file.rb')
          write_file('packs/chefs_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/artists_package_2/app/public/README.md', <<~CONTENTS)
            # This file should not be included in the stats
          CONTENTS

          write_file('packs/artists_package_2/app/some_package_file.rb')
          write_file('packs/artists_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/chefs_package_1/app/public/some_public_api_1.rb')
          write_file('packs/chefs_package_1/app/public/README.md', <<~CONTENTS)
            # This file should not be included in the stats
          CONTENTS

          write_file('packs/chefs_package_1/app/public/some_public_api_2.rb')
          write_file('packs/chefs_package_1/app/some_package_file.rb')
          write_file('packs/chefs_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 5, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 1, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 1, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.using_public_directory.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))

          expect(metrics).to include_metric GaugeMetric.for('by_team.all_files.count', 4, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_files.count', 4, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_files.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))

          expect(metrics).to include_metric GaugeMetric.for('by_team.public_files.count', 2, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.public_files.count', 2, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.public_files.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))

          expect(metrics).to include_metric GaugeMetric.for('by_package.public_files.count', 2, Tags.for(['package:packs/artists_package_1', 'team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.public_files.count', 0, Tags.for(['package:packs/artists_package_2', 'team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.public_files.count', 2, Tags.for(['package:packs/chefs_package_1', 'team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.public_files.count', 0, Tags.for(['package:packs/chefs_package_2', 'team:Chefs', 'app:MyApp']))
        end
      end

      context 'in an app with mixed usage of readmes' do
        before do
          write_file('config/teams/art/artists.yml', <<~CONTENTS)
            name: Artists
          CONTENTS

          write_file('config/teams/food/chefs.yml', <<~CONTENTS)
            name: Chefs
          CONTENTS

          write_file('empty_file.rb')
          write_file('package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/artists_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/artists_package_1/README.md', <<~CONTENTS)
            This is a readme.
          CONTENTS

          write_file('packs/chefs_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/artists_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/artists_package_2/README.md', <<~CONTENTS)
            This is a readme.
          CONTENTS

          write_file('packs/chefs_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/chefs_package_1/README.md', <<~CONTENTS)
            This is a readme.
          CONTENTS
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 5, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.has_readme.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.has_readme.count', 1, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.has_readme.count', 2, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.has_readme.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
        end
      end

      context 'in an app with users who set up their packages to get notified' do
        before do
          write_file('config/teams/art/artists.yml', <<~CONTENTS)
            name: Artists
          CONTENTS

          write_file('config/teams/food/chefs.yml', <<~CONTENTS)
            name: Chefs
          CONTENTS

          write_file('empty_file.rb')
          write_file('package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              notify_on_package_yml_changes: true
              notify_on_new_violations: true
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/artists_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
              notify_on_package_yml_changes: true
              notify_on_new_violations: true
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS

          write_file('packs/chefs_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
              notify_on_package_yml_changes: true
              notify_on_new_violations: true
              protections:
                prevent_this_package_from_violating_its_stated_dependencies: fail_never
                prevent_other_packages_from_using_this_packages_internals: fail_never
                prevent_this_package_from_exposing_an_untyped_api: fail_never
                prevent_this_package_from_creating_other_namespaces: fail_never
          CONTENTS
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('all_packages.notify_on_package_yml_changes.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.notify_on_new_violations.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.notify_on_package_yml_changes.count', 1, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.notify_on_new_violations.count', 1, Tags.for(['team:Chefs', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.notify_on_package_yml_changes.count', 1, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.notify_on_new_violations.count', 1, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.notify_on_package_yml_changes.count', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.notify_on_new_violations.count', 1, Tags.for(['team:Unknown', 'app:MyApp']))
        end
      end

      context 'in an app with nested packs' do
        before do
          write_package_yml('.')
          write_package_yml('packs/fruits')
          write_package_yml('packs/fruits/apples')
          write_package_yml('packs/fruits/pears')

          write_package_yml('packs/vegetables')
          write_package_yml('packs/vegetables/broccoli')

          write_package_yml('packs/peanuts')
          write_package_yml('packs/cashews')

          # Represents TWO privacy and TWO dependency violations across pack groups
          write_file('deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/fruits:
              "FruitsConstant":
                violations:
                - dependency
                - privacy
                files:
                - some_file1.rb
                - some_file2.rb
          CONTENTS

          # Represents ONE privacy and ZERO dependency violations across pack groups
          write_file('packs/fruits/deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/fruits/apples:
              "ApplesConstant":
                violations:
                - dependency
                - privacy
                files:
                - some_file1.rb
                - some_file2.rb
            packs/peanuts:
              "PeanutsConstant":
                violations:
                - privacy
                files:
                - some_file1.rb
          CONTENTS

          # Represents ZERO violations across pack groups
          write_file('packs/fruits/apples/deprecated_references.yml', <<~CONTENTS)
            # This file contains a list of dependencies that are not part of the long term plan for ..
            # We should generally work to reduce this list, but not at the expense of actually getting work done.
            #
            # You can regenerate this file using the following command:
            #
            # bundle exec packwerk update-deprecations .
            ---
            packs/fruits:
              "FruitsConstant":
                violations:
                - dependency
                - privacy
                files:
                - packs/fruits/apples/some_file1.rb
                - packs/fruits/apples/some_file2.rb
                - packs/fruits/apples/some_file3.rb
                - packs/fruits/apples/some_file4.rb
            packs/fruits/pears:
              "PearsConstant":
                violations:
                - dependency
                - privacy
                files:
                - packs/fruits/apples/some_file1.rb
                - packs/fruits/apples/some_file2.rb
                - packs/fruits/apples/some_file3.rb
                - packs/fruits/apples/some_file4.rb
            packs/peanuts:
              "PeanutsConstant":
                violations:
                - dependency
                files:
                - packs/fruits/apples/some_file1.rb
          CONTENTS
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 8, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_pack_groups.count', 5, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('child_packs.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('parent_packs.count', 2, Tags.for(['app:MyApp']))

          # Notice that this does not use a tag to specify the pack group -- the metric itself only sends information about cross-pack group violations
          expect(metrics).to include_metric GaugeMetric.for('all_pack_groups.privacy_violations.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_pack_groups.dependency_violations.count', 3, Tags.for(['app:MyApp']))

          # This does have a tag for pack group, but the metric itself also only sends information about cross-pack group violations.
          expect(metrics).to include_metric GaugeMetric.for('by_pack_group.outbound_dependency_violations.per_pack_group.count', 2, Tags.for(['app:MyApp', 'pack_group:root', 'to_pack_group:packs/fruits']))
          expect(metrics).to include_metric GaugeMetric.for('by_pack_group.outbound_privacy_violations.per_pack_group.count', 2, Tags.for(['app:MyApp', 'pack_group:root', 'to_pack_group:packs/fruits']))
          expect(metrics).to include_metric GaugeMetric.for('by_pack_group.outbound_dependency_violations.per_pack_group.count', 1, Tags.for(['app:MyApp', 'pack_group:packs/fruits', 'to_pack_group:packs/peanuts']))
        end
      end
    end
  end
end

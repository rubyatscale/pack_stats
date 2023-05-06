# frozen_string_literal: true

module PackStats # rubocop:disable RSpec/DescribedClassModuleWrapping
  RSpec.describe PackStats do
    before do
      ParsePackwerk.bust_cache!
      write_file('config/code_ownership.yml', YAML.dump({}))
    end

    describe 'PackStats.report_to_datadog!' do
      let(:report_to_datadog) do
        PackStats.report_to_datadog!(
          app_name: 'MyApp',
          source_code_pathnames: Pathname.glob('**/**.rb'),
          datadog_client: datadog_client,
          report_time: report_time,
        )
      end

      let(:datadog_client) { sorbet_double(Dogapi::Client) }
      let(:report_time) { Time.now } # rubocop:disable Rails/TimeZone

      let(:expected_metric) do
        GaugeMetric.for('some_metric', 11, Tags.for(['mykey:myvalue', 'myotherkey:myothervalue']))
      end

      before do
        allow(PackStats).to receive(:get_metrics).and_return([expected_metric])
      end

      it 'emits to datadog' do
        expect(datadog_client).to receive(:batch_metrics).and_yield # rubocop:disable RSpec/MessageSpies
        expect(datadog_client).to receive(:emit_points).with( # rubocop:disable RSpec/MessageSpies
          'modularization.some_metric',
          [[report_time, 11]],
          type: 'gauge',
          tags: ['mykey:myvalue', 'myotherkey:myothervalue', 'max_enforcements:false']
        )
        report_to_datadog
      end
    end

    describe 'PackStats.get_metrics' do
      let(:subject) do
        PackStats.get_metrics(
          app_name: 'MyApp',
          source_code_pathnames: Pathname.glob('**/**.rb'),
          componentized_source_code_locations: [Pathname.new('components')],
        )
      end
      let(:metrics) { subject }

      before do
        Packs.bust_cache!
        CodeTeams.bust_caches!
        CodeOwnership.bust_caches!
        write_package_yml('.')
        write_file('packs.yml', <<~YML)
        pack_paths:
          - packs/*
        YML
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
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.false.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.false.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.false.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.false.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.all_files.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.public_files.count', 0, Tags.for(['app:MyApp']))
        end

        it 'emits no metrics about rubocop exclusions' do
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.exclusions.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.exclusions.count', 0, Tags.for(['app:MyApp']))
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
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
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

      context 'in app that does not use package protectiosn with a simple package owned by one team' do
        include_context 'only one team'

        before do
          write_file('empty_file.rb')
          write_file('packs/only_package/app/some_package_file.rb')
          write_file('packs/only_package/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
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
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown']))
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
          CONTENTS

          write_file('packs/package_2/spec/some_package_file_spec.rb')
          write_file('packs/package_1/app/some_package_file.rb')
          write_file('packs/package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
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
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
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
          write_file('package_todo.yml', <<~CONTENTS)
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
          CONTENTS

          write_file('empty_file_to_keep_directory.rb')
          write_file('packs/package_2/package_todo.yml', <<~CONTENTS)
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
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.true.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 5, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 3, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 2, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:packs/package_1', 'to_team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:packs/package_1', 'to_team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Chefs', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 2, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Artists']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 3, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 2, Tags.for(['package:root', 'app:MyApp', 'team:Unknown']))
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
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_privacy_violations.count', 0, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.inbound_privacy_violations.count', 0, Tags.for(['team:Artists', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.all_packages.count', 1, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.dependency_violations.count', 3, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.privacy_violations.count', 0, Tags.for(['team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_team.outbound_dependency_violations.count', 2, Tags.for(['team:Unknown', 'app:MyApp']))
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
          write_file('package_todo.yml', <<~CONTENTS)
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
          CONTENTS

          write_file('empty_file_to_keep_directory.rb')
          write_file('packs/package_2/package_todo.yml', <<~CONTENTS)
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
          CONTENTS

          write_file('packs/package_2/spec/some_package_file_spec.rb')
          write_file('packs/package_1/package_todo.yml', <<~CONTENTS)
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
          CONTENTS

          write_file('packs/package_1/spec/some_package_file_spec.rb')
          write_file('components/my_component_2/spec/my_file_spec.rb')
          write_file('components/my_component_2/lib/my_component_2/my_file.rb')
          write_file('components/my_component_2/lib/my_component_2.rb')
          write_file('components/my_component_3/spec/my_file_spec.rb')
          write_file('components/my_component_3/lib/my_component_3/my_file.rb')
          write_file('components/my_component_3/lib/my_component_3.rb')
        end

        # The purpose of this spec is to have a clear list of all of the metrics that are supported by pack_stats
        # We can also look at the diff of this list to easily see what metrics are being added or removed
        it 'emits only these metrics' do
          expect(metrics.map(&:name).uniq.sort).to match_array %w(
            modularization.all_files.by_team
            modularization.all_files.totals
            modularization.all_packages.all_files.count
            modularization.all_packages.count
            modularization.all_packages.dependencies.count
            modularization.all_packages.dependency_violations.count
            modularization.all_packages.enforcing_dependencies.count
            modularization.all_packages.enforcing_privacy.count
            modularization.all_packages.has_readme.count
            modularization.all_packages.package_based_file_ownership.count
            modularization.all_packages.packwerk_checkers.enforce_dependencies.false.count
            modularization.all_packages.packwerk_checkers.enforce_dependencies.strict.count
            modularization.all_packages.packwerk_checkers.enforce_dependencies.true.count
            modularization.all_packages.packwerk_checkers.enforce_privacy.false.count
            modularization.all_packages.packwerk_checkers.enforce_privacy.strict.count
            modularization.all_packages.packwerk_checkers.enforce_privacy.true.count
            modularization.all_packages.privacy_violations.count
            modularization.all_packages.public_files.count
            modularization.all_packages.rubocops.packs_classmethodsaspublicapis.exclusions.count
            modularization.all_packages.rubocops.packs_classmethodsaspublicapis.false.count
            modularization.all_packages.rubocops.packs_classmethodsaspublicapis.strict.count
            modularization.all_packages.rubocops.packs_classmethodsaspublicapis.true.count
            modularization.all_packages.rubocops.packs_documentedpublicapis.exclusions.count
            modularization.all_packages.rubocops.packs_documentedpublicapis.false.count
            modularization.all_packages.rubocops.packs_documentedpublicapis.strict.count
            modularization.all_packages.rubocops.packs_documentedpublicapis.true.count
            modularization.all_packages.rubocops.packs_rootnamespaceispackname.exclusions.count
            modularization.all_packages.rubocops.packs_rootnamespaceispackname.false.count
            modularization.all_packages.rubocops.packs_rootnamespaceispackname.strict.count
            modularization.all_packages.rubocops.packs_rootnamespaceispackname.true.count
            modularization.all_packages.rubocops.packs_typedpublicapis.exclusions.count
            modularization.all_packages.rubocops.packs_typedpublicapis.false.count
            modularization.all_packages.rubocops.packs_typedpublicapis.strict.count
            modularization.all_packages.rubocops.packs_typedpublicapis.true.count
            modularization.all_packages.using_public_directory.count
            modularization.all_packages.with_violations.count
            modularization.by_package.all_files.count
            modularization.by_package.dependency_violations.count
            modularization.by_package.inbound_explicit_dependencies.count
            modularization.by_package.inbound_privacy_violations.count
            modularization.by_package.outbound_dependency_violations.count
            modularization.by_package.outbound_dependency_violations.per_package.count
            modularization.by_package.outbound_explicit_dependencies.count
            modularization.by_package.outbound_explicit_dependencies.per_package.count
            modularization.by_package.outbound_privacy_violations.count
            modularization.by_package.outbound_privacy_violations.per_package.count
            modularization.by_package.privacy_violations.count
            modularization.by_package.public_files.count
            modularization.by_package.using_public_directory.count
            modularization.by_team.all_files.count
            modularization.by_team.all_packages.count
            modularization.by_team.dependency_violations.count
            modularization.by_team.has_readme.count
            modularization.by_team.inbound_privacy_violations.count
            modularization.by_team.outbound_dependency_violations.count
            modularization.by_team.outbound_dependency_violations.per_team.count
            modularization.by_team.outbound_privacy_violations.count
            modularization.by_team.outbound_privacy_violations.per_team.count
            modularization.by_team.packwerk_checkers.enforce_dependencies.false.count
            modularization.by_team.packwerk_checkers.enforce_dependencies.strict.count
            modularization.by_team.packwerk_checkers.enforce_dependencies.true.count
            modularization.by_team.packwerk_checkers.enforce_privacy.false.count
            modularization.by_team.packwerk_checkers.enforce_privacy.strict.count
            modularization.by_team.packwerk_checkers.enforce_privacy.true.count
            modularization.by_team.privacy_violations.count
            modularization.by_team.public_files.count
            modularization.by_team.using_public_directory.count
            modularization.component_files.by_team
            modularization.component_files.totals
            modularization.packaged_files.by_team
            modularization.packaged_files.totals
          )
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
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.true.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.true.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.true.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.strict.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 6, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 3, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 4, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 2, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 3, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:packs/package_1', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:packs/package_1', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 1, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown', 'to_package:root', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 3, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 2, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.per_package.count', 0, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_2', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.per_package.count', 1, Tags.for(['package:packs/package_1', 'team:Unknown', 'app:MyApp', 'to_package:packs/package_2', 'to_team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 3, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 1, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 2, Tags.for(['package:root', 'team:Unknown', 'app:MyApp']))
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
          CONTENTS

          write_file('packs/package_2/package_rubocop.yml', <<~CONTENTS)
            Packs/TypedPublicApis:
              Enabled: true
          CONTENTS

          write_file('packs/package_3/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: strict
            metadata:
              other_stuff: is_irrelevant
          CONTENTS

          write_file('packs/package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: strict
            enforce_privacy: strict
          CONTENTS

          write_file('packs/package_1/package_rubocop.yml', <<~CONTENTS)
            Packs/TypedPublicApis:
              Enabled: true
              FailureMode: strict

            Packs/RootNamespaceIsPackName:
              Enabled: true
              FailureMode: strict
          CONTENTS
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.for('component_files.totals', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('packaged_files.totals', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_files.totals', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.count', 4, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependencies.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.dependency_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.privacy_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_dependencies.count', 3, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.enforcing_privacy.count', 4, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.with_violations.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.strict.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_dependencies.true.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.strict.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.packwerk_checkers.enforce_privacy.true.count', 2, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.strict.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.true.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.strict.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.package_based_file_ownership.count', 0, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.using_public_directory.count', 1, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_2', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_privacy_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.inbound_privacy_violations.count', 0, Tags.for(['package:packs/package_3', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.privacy_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
          expect(metrics).to include_metric GaugeMetric.for('by_package.outbound_dependency_violations.count', 0, Tags.for(['package:packs/package_1', 'app:MyApp', 'team:Unknown']))
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
          CONTENTS

          write_file('packs/artists_package_1/app/public/some_subdir/some_public_api_1.rb')
          write_file('packs/artists_package_1/app/public/some_subdir/some_public_api_2.rb')
          write_file('packs/artists_package_1/app/some_package_file.rb')
          write_file('packs/artists_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
          CONTENTS

          write_file('packs/chefs_package_2/app/some_package_file.rb')
          write_file('packs/chefs_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
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
          CONTENTS

          write_file('packs/artists_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
          CONTENTS

          write_file('packs/artists_package_1/README.md', <<~CONTENTS)
            This is a readme.
          CONTENTS

          write_file('packs/chefs_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
          CONTENTS

          write_file('packs/artists_package_2/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Artists
          CONTENTS

          write_file('packs/artists_package_2/README.md', <<~CONTENTS)
            This is a readme.
          CONTENTS

          write_file('packs/chefs_package_1/package.yml', <<~CONTENTS)
            enforce_dependencies: false
            enforce_privacy: false
            metadata:
              owner: Chefs
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

      context 'in an app with exclusions for rubocop based protections' do
        before do
          write_package_yml('.')
          write_package_yml('packs/foo')
          write_package_yml('packs/foo/bar')
          write_package_yml('packs/foo/baz')
          write_package_yml('packs/apples')
          write_file('.rubocop_todo.yml', <<~YML)
            Packs/RootNamespaceIsPackName:
              Exclude:
                - app/services/my_file1.rb
                - app/services/my_file2.rb
            Packs/TypedPublicApis:
              Exclude:
                - app/services/my_file1.rb
                - app/services/my_file2.rb
          YML

          write_file('packs/foo/package_rubocop_todo.yml', <<~YML)
            Packs/RootNamespaceIsPackName:
              Exclude:
                - packs/foo/app/services/my_file1.rb
                - packs/foo/app/services/my_file2.rb
            Packs/TypedPublicApis:
              Exclude:
                - packs/foo/app/services/my_file1.rb
                - packs/foo/app/services/my_file2.rb
          YML

          write_file('packs/foo/bar/package_rubocop_todo.yml', <<~YML)
            Packs/RootNamespaceIsPackName:
              Exclude:
                - packs/foo/bar/app/services/my_file1.rb
                - packs/foo/bar/app/services/my_file2.rb
            Packs/TypedPublicApis:
              Exclude:
                - packs/foo/bar/app/services/my_file1.rb
                - packs/foo/bar/app/services/my_file2.rb
          YML
        end

        it 'emits metrics about rubocop exclusions' do
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_typedpublicapis.exclusions.count', 6, Tags.for(['app:MyApp']))
          expect(metrics).to include_metric GaugeMetric.for('all_packages.rubocops.packs_rootnamespaceispackname.exclusions.count', 6, Tags.for(['app:MyApp']))
        end
      end

      context 'when getting metrics after turning all protections to max' do
        let(:subject) do
          PackStats.get_metrics(
            app_name: 'MyApp',
            source_code_pathnames: Pathname.glob('**/**.rb'),
            componentized_source_code_locations: [Pathname.new('components')],
            max_enforcements_tag_value: true
          )
        end

        include_context 'only one team'

        before do
          write_file('empty_file.rb')
          write_file('packs/only_package/app/some_package_file.rb')
          write_file('packs/only_package/package.yml', <<~CONTENTS)
            enforce_dependencies: true
            enforce_privacy: true
          CONTENTS

          write_file('packs/only_package/spec/some_package_file_spec.rb')
        end

        it 'emits the right metrics' do
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.component_files.by_team', count: 0, tags: Tags.for(['team:Some team', 'app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.packaged_files.by_team', count: 2, tags: Tags.for(['team:Some team', 'app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_files.by_team', count: 3, tags: Tags.for(['team:Some team', 'app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.component_files.totals', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.packaged_files.totals', count: 2, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_files.totals', count: 3, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.count', count: 2, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.dependencies.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.dependency_violations.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.privacy_violations.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.enforcing_dependencies.count', count: 2, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.enforcing_privacy.count', count: 2, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.with_violations.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.packwerk_checkers.enforce_dependencies.strict.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.packwerk_checkers.enforce_dependencies.true.count', count: 2, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.packwerk_checkers.enforce_privacy.strict.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.packwerk_checkers.enforce_privacy.true.count', count: 2, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.rubocops.packs_typedpublicapis.strict.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.rubocops.packs_typedpublicapis.true.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.rubocops.packs_rootnamespaceispackname.strict.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.package_based_file_ownership.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.using_public_directory.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.dependency_violations.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.privacy_violations.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.outbound_dependency_violations.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.outbound_privacy_violations.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.inbound_privacy_violations.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.outbound_explicit_dependencies.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.inbound_explicit_dependencies.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.using_public_directory.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.all_files.count', count: 2, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.all_packages.public_files.count', count: 0, tags: Tags.for(['app:MyApp', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_team.using_public_directory.count', count: 0, tags: Tags.for(['app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_team.all_files.count', count: 2, tags: Tags.for(['app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_team.public_files.count', count: 0, tags: Tags.for(['app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.using_public_directory.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.all_files.count', count: 2, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))
          expect(metrics).to include_metric GaugeMetric.new(name: 'modularization.by_package.public_files.count', count: 0, tags: Tags.for(['package:packs/only_package', 'app:MyApp', 'team:Unknown', 'max_enforcements:true']))        end
      end
    end
  end
end

# typed: strict
# frozen_string_literal: true

module PackStats
  module Private
    module Metrics
      extend T::Sig
      UNKNOWN_OWNER = T.let('Unknown', String)

      sig { params(team_name: T.nilable(String)).returns(T::Array[Tag]) }
      def self.tags_for_team(team_name)
        [Tag.for('team', team_name || UNKNOWN_OWNER)]
      end

      sig { params(package: ParsePackwerk::Package, app_name: String).returns(T::Array[Tag]) }
      def self.tags_for_package(package, app_name)

        tags = [
          Tag.new(key: 'package', value: humanized_package_name(package.name)),
          Tag.new(key: 'app', value: app_name),
          *Metrics.tags_for_team(Private.package_owner(package)),
        ]

        layer = package.config['layer']
        if layer
          tags << Tag.new(key: 'layer', value: layer)
        end

        tags
      end

      sig { params(team_name: T.nilable(String)).returns(T::Array[Tag]) }
      def self.tags_for_other_team(team_name)
        [Tag.for('other_team', team_name || Metrics::UNKNOWN_OWNER)]
      end

      sig { params(name: String).returns(String) }
      def self.humanized_package_name(name)
        if name == ParsePackwerk::ROOT_PACKAGE_NAME
          'root'
        else
          name
        end
      end

      sig { params(violations: T::Array[ParsePackwerk::Violation]).returns(Integer) }
      def self.file_count(violations)
        violations.sum { |v| v.files.count }
      end

      sig { params(package: ParsePackwerk::Package).returns(T::Boolean) }
      def self.has_readme?(package)
        package.directory.join('README.md').exist?
      end
    end
  end
end

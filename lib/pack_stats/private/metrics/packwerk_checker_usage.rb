# typed: strict
# frozen_string_literal: true

require 'rubocop-packs'

module PackStats
  module Private
    module Metrics
      class PackwerkCheckerUsage
        extend T::Sig

        # Some violations (e.g. dependency, visibility, architecture) matter for the referencing (outbound) package.
        # Other violations (e.g. privacy) matter for the referenced (inbound) package.
        class Direction < T::Enum
          enums do
            Inbound = new
            Outbound = new
          end
        end

        # Later, we might find a way we can get this directly from `packwerk`
        class PackwerkChecker < T::Struct
          extend T::Sig

          const :setting, String
          const :violation_type, String
          const :direction, Direction

          sig { returns(Tag) }
          def violation_type_tag
            Tag.new(
              key: 'violation_type',
              value: violation_type
            )
          end
        end

        CHECKERS = T.let([
          PackwerkChecker.new(setting: 'enforce_dependencies', violation_type: 'dependency', direction: Direction::Outbound),
          PackwerkChecker.new(setting: 'enforce_privacy', violation_type: 'privacy', direction: Direction::Inbound),
          PackwerkChecker.new(setting: 'enforce_architecture', violation_type: 'architecture', direction: Direction::Outbound),
          PackwerkChecker.new(setting: 'enforce_visibility', violation_type: 'visibility', direction: Direction::Outbound),
        ], T::Array[PackwerkChecker])

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_checker_metrics(prefix, packages, package_tags)
          metrics = T.let([], T::Array[GaugeMetric])

          CHECKERS.each do |checker|
            ['false', 'true', 'strict'].each do |enabled_mode|
              count_of_packages = ParsePackwerk.all.count do |package|
                checker_setting = YAML.load_file(package.yml)[checker.setting]
                case enabled_mode
                when 'false'
                  !checker_setting
                when 'true'
                  checker_setting && checker_setting != 'strict'
                when 'strict'
                  checker_setting == 'strict'
                end
              end

              metric_name = "#{prefix}.packwerk_checkers.#{enabled_mode}.count"
              tags = package_tags + [checker.violation_type_tag]
              metrics << GaugeMetric.for(metric_name, count_of_packages, tags)
            end
          end

          metrics
        end
      end
    end
  end
end

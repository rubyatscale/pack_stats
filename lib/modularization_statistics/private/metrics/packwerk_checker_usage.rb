# typed: strict
# frozen_string_literal: true

require 'rubocop-packs'

module ModularizationStatistics
  module Private
    module Metrics
      class PackwerkCheckerUsage
        extend T::Sig
        
        # Later, we might find a way we can get this directly from `packwerk`
        class PackwerkChecker < T::Struct
          const :setting, String
          const :strict_mode, String
        end

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_checker_metrics(prefix, packages, package_tags)
          metrics = T.let([], T::Array[GaugeMetric])

          checkers = [
            PackwerkChecker.new(setting: 'enforce_dependencies', strict_mode: 'enforce_dependencies_strictly'),
            PackwerkChecker.new(setting: 'enforce_privacy', strict_mode: 'enforce_privacy_strictly')
          ]

          checkers.each do |checker|
            ['false', 'true', 'strict'].each do |enabled_mode|
              count_of_packages = ParsePackwerk.all.count do |package|
                strict_mode = package.metadata[checker.strict_mode]
                enabled = YAML.load_file(package.yml)[checker.setting]
                case enabled_mode
                when 'false'
                  !enabled
                when 'true'
                  enabled && !strict_mode
                when 'strict'
                  !!strict_mode
                end
              end

              metric_name = "#{prefix}.packwerk_checkers.#{checker.setting}.#{enabled_mode}.count"
              metrics << GaugeMetric.for(metric_name, count_of_packages, package_tags)
            end
          end

          metrics
        end
      end
    end
  end
end

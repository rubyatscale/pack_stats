# typed: strict
# frozen_string_literal: true

require 'rubocop-packs'

module PackStats
  module Private
    module Metrics
      class PackwerkCheckerUsage
        extend T::Sig
        
        # Later, we might find a way we can get this directly from `packwerk`
        class PackwerkChecker < T::Struct
          const :setting, String
        end

        sig { params(prefix: String, packages: T::Array[ParsePackwerk::Package], package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric]) }
        def self.get_checker_metrics(prefix, packages, package_tags)
          metrics = T.let([], T::Array[GaugeMetric])

          checkers = [
            PackwerkChecker.new(setting: 'enforce_dependencies'),
            PackwerkChecker.new(setting: 'enforce_privacy')
          ]

          checkers.each do |checker|
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

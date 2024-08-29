# typed: strict
# frozen_string_literal: true

module PackStats
  module Private
    module Metrics
      class PublicUsage
        extend T::Sig

        sig do
          params(prefix: String, packages: T::Array[ParsePackwerk::Package],
                 package_tags: T::Array[Tag]).returns(T::Array[GaugeMetric])
        end
        def self.get_public_usage_metrics(prefix, packages, package_tags)
          packages_except_for_root = packages.reject { |package| package.name == ParsePackwerk::ROOT_PACKAGE_NAME }
          all_files = packages_except_for_root.flat_map do |package|
            package.directory.glob('**/**.rb')
          end

          all_public_files = T.let([], T::Array[Pathname])
          is_using_public_directory = 0
          packages_except_for_root.each do |package|
            public_files = package.directory.glob('app/public/**/**.rb')
            all_public_files += public_files
            is_using_public_directory += 1 if public_files.any?
          end

          # In Datadog, we can divide public files by all files to get the ratio.
          # This is not a metric that we are targeting -- its for observability and reflection only.
          [
            GaugeMetric.for("#{prefix}.all_files.count", all_files.count, package_tags),
            GaugeMetric.for("#{prefix}.public_files.count", all_public_files.count, package_tags),
            GaugeMetric.for("#{prefix}.using_public_directory.count", is_using_public_directory, package_tags)
          ]
        end
      end
    end
  end
end

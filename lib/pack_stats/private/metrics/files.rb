# typed: strict
# frozen_string_literal: true

module PackStats
  module Private
    module Metrics
      class Files
        extend T::Sig

        sig do
          params(
            source_code_files: T::Array[SourceCodeFile],
            app_name: String
          ).returns(T::Array[GaugeMetric])
        end
        def self.get_metrics(source_code_files, app_name)
          all_metrics = T.let([], T::Array[GaugeMetric])
          app_level_tag = Tag.for('app', app_name)

          source_code_files.group_by { |file| file.team_owner&.name }.each do |team_name, files_for_team|
            file_tags = Metrics.tags_for_team(team_name) + [app_level_tag]
            all_metrics += get_file_metrics('by_team', file_tags, files_for_team)
          end

          file_tags = [app_level_tag]
          all_metrics += get_file_metrics('totals', file_tags, source_code_files)
          all_metrics
        end

        sig do
          params(
            metric_name_suffix: String,
            tags: T::Array[Tag],
            files: T::Array[SourceCodeFile]
          ).returns(T::Array[GaugeMetric])
        end
        def self.get_file_metrics(metric_name_suffix, tags, files)
          [
            GaugeMetric.for("component_files.#{metric_name_suffix}", files.count(&:componentized_file?), tags),
            GaugeMetric.for("packaged_files.#{metric_name_suffix}", files.count(&:packaged_file?), tags),
            GaugeMetric.for("all_files.#{metric_name_suffix}", files.count, tags),
          ]
        end
      end
    end
  end
end

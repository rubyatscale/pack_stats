# typed: strict

module PackStats
  class GaugeMetric < T::Struct
    extend T::Sig

    const :name, String
    const :count, Integer
    const :tags, T::Array[Tag]

    sig { params(metric_name: String, count: Integer, tags: T::Array[Tag]).returns(GaugeMetric) }
    def self.for(metric_name, count, tags)
      # This can be incremented with new tests
      name = "test.0.modularization.#{metric_name}"
      # https://docs.datadoghq.com/metrics/custom_metrics/#naming-custom-metrics
      # Metric names must not exceed 200 characters. Fewer than 100 is preferred from a UI perspective
      if name.length > 200
        raise StandardError.new("Metrics names must not exceed 200 characters: #{name}") # rubocop:disable Style/RaiseArgs
      end

      all_tags = [*tags, max_enforcements_tag]
      new(
        name: name,
        count: count,
        tags: all_tags
      )
    end

    sig { returns(String) }
    def to_s
      "#{name} with count #{count}, with tags #{tags.map(&:to_s).join(', ')}"
    end

    sig { params(other: GaugeMetric).returns(T::Boolean) }
    def ==(other)
      other.name == self.name &&
        other.count == self.count &&
        other.tags == self.tags
    end

    sig { params(tag_value: T::Boolean).void }
    def self.set_max_enforcements_tag(tag_value)
      @max_enforcements_tag = T.let(@max_enforcements_tag, T.nilable(Tag))
      @max_enforcements_tag = Tag.new(key: 'max_enforcements', value: tag_value ? 'true' : 'false')
    end

    sig { returns(Tag) }
    def self.max_enforcements_tag
      @max_enforcements_tag || Tag.new(key: 'max_enforcements', value: 'false')
    end
  end
end

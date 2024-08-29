# typed: strict

module PackStats
  class Tag < T::Struct
    extend T::Sig
    const :key, String
    const :value, String

    sig { returns(String) }
    def to_s
      "#{key}:#{value}"
    end

    sig { params(key: String, value: String).returns(Tag) }
    def self.for(key, value)
      new(
        key: key,
        value: value
      )
    end

    sig { params(other: Tag).returns(T::Boolean) }
    def ==(other)
      other.key == key &&
        other.value == value
    end
  end
end

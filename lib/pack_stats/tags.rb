# typed: strict

module PackStats
  module Tags
    extend T::Sig

    sig { params(colon_delimited_tag_strings: T::Array[String]).returns(T::Array[Tag]) }
    def self.for(colon_delimited_tag_strings)
      colon_delimited_tag_strings.map do |colon_delimited_tag_string|
        key, value = colon_delimited_tag_string.split(':')
        raise StandardError, "Improperly formatted tag `#{colon_delimited_tag_string}`" if key.nil? || value.nil?

        Tag.new(
          key: key,
          value: value
        )
      end
    end
  end
end

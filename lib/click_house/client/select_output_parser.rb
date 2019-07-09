module ClickHouse
  class Client
    # @see https://clickhouse.yandex/docs/en/interfaces/formats/
    module SelectOutputParser
      ESCAPE_SEQUENCES = {
        '\\b' => "\b",
        '\\f' => "\f",
        '\\r' => "\r",
        '\\n' => "\n",
        '\\t' => "\t",
        '\\0' => "\0",
        "\\'" => "'",
        "\\\\" => "\\",
      }.freeze
      # @see https://clickhouse.yandex/docs/en/interfaces/formats/#tabseparated
      TYPED_PARSER_BUILDER = lambda do |type|
        case type
        when /^Array\((.+)\)$/
          item_builder = TYPED_PARSER_BUILDER.call(Regexp.last_match[1])
          ->(value) { value.match(/^\[(.*)\]$/)[1].split(',').map(&item_builder) }
        when /^Nullable\((.+)\)$/
          not_null_builder = TYPED_PARSER_BUILDER.call(Regexp.last_match[1])
          ->(value) { not_null_builder.call(value) unless value == '\N' }
        when /^U?Int(?:8|16|32|64)$/
          :to_i
        when /^Float(?:32|64)$/
          :to_f
        when /^Enum(?:8|16)\(.+\)$/, /^FixedString\(\d+\)$/, 'String'
          lambda do |value|
            ESCAPE_SEQUENCES.inject(value) do |value_accumulator, (pattern, replacement)|
              value_accumulator.gsub(pattern, replacement)
            end.gsub(/\A'(.*)'\z/, '\1')
          end
        when 'Date'
          ->(value) { Date.strptime(value, '%Y-%m-%d') }
        when 'DateTime'
          ->(value) { DateTime.strptime(value, '%Y-%m-%d %H:%M:%S') }
        when 'Nothing' then ->(_) {}
        else
          fail NotImplementedError, "Unknown type #{type.inspect}"
        end.to_proc
      end

      def self.tab_separated_with_names_and_types(body, **options)
        fail ArgumentError unless options.empty?
        Enumerator.new do |y|
          TSV.parse(body).inject(nil) do |types, row|
            types&.tap do
              y << types.zip(row.to_a).map { |type, value| type.call(value) }
            end || row.map(&TYPED_PARSER_BUILDER)
          end
        end
      end

      def self.tab_separated(body, types:)
        TSV.parse(body).without_header.lazy.map do |row|
          types.zip(row.to_a).map { |type, value| type.call(value) }
        end
      end
    end
  end
end
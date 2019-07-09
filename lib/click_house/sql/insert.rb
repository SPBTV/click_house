# frozen_string_literal: true

module ClickHouse
  module SQL
    # https://clickhouse.yandex/docs/en/query_language/insert_into/
    module Insert
      extend SQL

      # @param into [#to_s, (#to_s, #to_s)]
      # @param columns [<#to_s>, nil]
      # @param rows [<<*>>, nil]
      # @return [String]
      def self.call(into:, columns: nil, rows: nil)
        [
          "INSERT INTO #{Array(into).map { |identifier| quote_identifier(identifier) }.join('.')}",
          ("(#{columns.map { |column| Array(column).join('.') }.join(',')})" if columns),
          (values(rows) if rows),
        ].compact.join(' ')
      end

      # @param rows [<<*>>]
      # @return [String]
      def self.values(rows)
        "VALUES #{rows.map { |row| "(#{row.map { |value| quote(value) }.join(',')})" }.join(',')}"
      end
    end
  end
end

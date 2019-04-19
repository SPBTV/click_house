# frozen_string_literal: true

RSpec.describe ClickHouse::Client do
  let(:client) { described_class.new(http_interface: http_interface) }
  let(:http_interface) { ClickHouse::HTTPInterface.new }

  describe '#each_selected_row' do
    def select_sql_expression(sql)
      client.select_from_sql(<<-SQL, format: :tab_separated_with_names_and_types)[0][0]
        SELECT #{sql} FROM system.one FORMAT TSVWithNamesAndTypes
      SQL
    end

    context 'when value is a string containing quote' do
      subject { select_sql_expression("'\\''") }

      it { is_expected.to eq("'") }
    end

    context 'when value is an array containing string' do
      subject { select_sql_expression("['a']") }

      it { is_expected.to eq(['a']) }
    end

    context 'when value is a null string' do
      subject { select_sql_expression('CAST(NULL AS Nullable(String))') }

      it { is_expected.to eq(nil) }
    end

    context 'when value is nothing' do
      subject { select_sql_expression('NULL') }

      it { is_expected.to eq(nil) }
    end

    context 'when value is an integer' do
      subject { select_sql_expression('42') }

      it { is_expected.to eq(42) }
    end

    context 'when value is a float' do
      subject { select_sql_expression('0.5') }

      it { is_expected.to eq(0.5) }
    end

    context 'when value is a date' do
      subject { select_sql_expression("toDate('1994-03-14')") }

      it { is_expected.to eq(Date.new(1994, 3, 14)) }
    end

    context 'when value is a date-time' do
      subject { select_sql_expression("toDateTime('1994-03-14 12:34:56')") }

      it { is_expected.to eq(DateTime.new(1994, 3, 14, 12, 34, 56)) }
    end

    context 'when value is a enum' do
      subject { select_sql_expression("CAST('world' AS Enum8('hello' = 1, 'world' = 2))") }

      it { is_expected.to eq('world') }
    end
  end
end

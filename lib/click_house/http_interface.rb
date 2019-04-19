# frozen_string_literal: true

module ClickHouse
  # https://clickhouse.yandex/docs/en/interfaces/http_interface/
  class HTTPInterface
    def initialize(**options)
      if options.key?(:url)
        initialize_from_url options
      else
        initialize_from_uri_components options
      end
    end

    def get(**options)
      request(Net::HTTP::Get, options)
    end

    def post(**options)
      request(Net::HTTP::Post, options)
    end

    private

    attr_reader :query_hash

    def initialize_from_url(url:)
      @uri = URI.parse(url)
    end

    DEFAULT_URI_COMPONENTS = {
      host: 'localhost',
      port: 8123
    }.freeze
    URI_COMPONENT_OPTIONS = %i[host port scheme].freeze
    QUERY_HASH_OPTIONS = %i[database password user].freeze

    def initialize_from_uri_components(**options)
      assert_option_keys options, URI_COMPONENT_OPTIONS | QUERY_HASH_OPTIONS
      @query_hash = options.slice(*QUERY_HASH_OPTIONS)

      @uri = URI::HTTP.build(
        **DEFAULT_URI_COMPONENTS,
        query: (URI.encode_www_form(query_hash) unless query_hash.empty?),
        **options.slice(*URI_COMPONENT_OPTIONS),
      )
    end

    def uri_with_params(params)
      if params.empty?
        @uri
      else
        @uri.dup.tap do |uri|
          uri.query = URI.encode_www_form([query_hash, params].compact.reduce(:merge))
        end
      end
    end

    def request(request_class, body: nil, params: {}, **options)
      assert_option_keys options, %i[query]
      Net::HTTP.start(@uri.host, @uri.port) do |http|
        response = http.request(request_class.new(uri_with_params(options.merge(params))), body)
        fail response.body unless response.is_a?(Net::HTTPSuccess)

        # https://github.com/yandex/ClickHouse/issues/2976
        response.body.force_encoding('ASCII-8BIT')
      end
    end

    def assert_option_keys(options, keys)
      return if (unexpected_options = options.keys - keys).empty?

      fail ArgumentError, "Unexpected options – #{unexpected_options.join(', ')}"
    end
  end
end

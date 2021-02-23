module Lamby
  class RackAlb < Lamby::Rack

    def alb?
      true
    end

    def multi_value?
      event.key? 'multiValueHeaders'
    end

    def response(handler)
      hhdrs = handler.headers
      multivalue_headers = hhdrs.transform_values { |v| v.split("\n").compact.flatten } if multi_value?
      status_description = "#{handler.status} #{::Rack::Utils::HTTP_STATUS_CODES[handler.status]}"
      base64_encode = hhdrs['Content-Transfer-Encoding'] == 'binary' || hhdrs['X-Lamby-Base64'] == '1'
      body = Base64.strict_encode64(handler.body) if base64_encode
      { multiValueHeaders: multivalue_headers,
        statusDescription: status_description,
        isBase64Encoded: base64_encode,
        body: body }.compact
    end

    private

    def env_base
      { ::Rack::REQUEST_METHOD => event['httpMethod'],
        ::Rack::SCRIPT_NAME => '',
        ::Rack::PATH_INFO => event['path'] || '',
        ::Rack::QUERY_STRING => query_string,
        ::Rack::SERVER_NAME => headers['host'],
        ::Rack::SERVER_PORT => headers['x-forwarded-port'],
        ::Rack::SERVER_PROTOCOL => 'HTTP/1.1',
        ::Rack::RACK_VERSION => ::Rack::VERSION,
        ::Rack::RACK_URL_SCHEME => headers['x-forwarded-proto'],
        ::Rack::RACK_INPUT => StringIO.new(body || ''),
        ::Rack::RACK_ERRORS => $stderr,
        ::Rack::RACK_MULTITHREAD => false,
        ::Rack::RACK_MULTIPROCESS => false,
        ::Rack::RACK_RUNONCE => false,
        LAMBDA_EVENT => event,
        LAMBDA_CONTEXT => context
      }.tap do |env|
        ct = content_type
        cl = content_length
        env['CONTENT_TYPE'] = ct if ct
        env['CONTENT_LENGTH'] = cl if cl
      end
    end

    def headers
      @headers ||= multi_value? ? headers_multi : super
    end

    def headers_multi
      Hash[(event['multiValueHeaders'] || {}).map do |k,v|
        if v.is_a?(Array)
          if k == 'x-forwarded-for'
            [k, v.join(', ')]
          else
            [k, v.first]
          end
        else
          [k,v]
        end
      end]
    end

  end
end

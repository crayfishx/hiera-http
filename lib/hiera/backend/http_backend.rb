class Hiera
  module Backend
    class Http_backend

      def initialize
        require 'net/http'
        require 'net/https'
        @config = Config[:http]

        @http = Net::HTTP.new(@config[:host], @config[:port])
        @http.read_timeout = @config[:http_read_timeout] || 10
        @http.open_timeout = @config[:http_connect_timeout] || 10

        @cache = {}
        @cache_timeout = @config[:cache_timeout] || 10
        @cache_clean_interval = @config[:cache_clean_interval] || 3600

        if @config[:use_ssl]
          @http.use_ssl = true

          if @config[:ssl_verify] == false
            @http.verify_mode = OpenSSL::SSL::VERIFY_NONE
          else
            @http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          end

          if @config[:ssl_cert]
            store = OpenSSL::X509::Store.new
            store.add_cert(OpenSSL::X509::Certificate.new(File.read(@config[:ssl_ca_cert])))
            @http.cert_store = store

            @http.key = OpenSSL::PKey::RSA.new(File.read(@config[:ssl_cert]))
            @http.cert = OpenSSL::X509::Certificate.new(File.read(@config[:ssl_key]))
          end
        else
          @http.use_ssl = false
        end
      end

      def lookup(key, scope, order_override, resolution_type)
        answer = nil

        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        paths.insert(0, order_override) if order_override


        paths.each do |path|

          Hiera.debug("[hiera-http]: Lookup #{key} from #{@config[:host]}:#{@config[:port]}#{path}")

          result = http_get_and_parse_with_cache(path)
          result = result[key] if result.is_a?(Hash)
          next if result.nil?

          parsed_result = Backend.parse_answer(result, scope)

          case resolution_type
          when :array
            answer ||= []
            answer << parsed_result
          when :hash
            answer ||= {}
            answer = Backend.merge_answer(parsed_result, answer)
          else
            answer = parsed_result
            break
          end
        end
        answer
      end


      private

      def parse_response(answer)
        return unless answer

        format = @config[:output] || 'plain'
        Hiera.debug("[hiera-http]: Query returned data, parsing response as #{format}")

        case format
        when 'json'
          parse_json answer
        when 'yaml'
          parse_yaml answer
        else
          answer
        end
      end

      # Handlers
      # Here we define specific handlers to parse the output of the http request
      # and return its structured representation.  Currently we support YAML and JSON
      #
      def parse_json(answer)
        require 'rubygems'
        require 'json'
        JSON.parse(answer)
      end

      def parse_yaml(answer)
        require 'yaml'
        YAML.parse(answer)
      end

      def http_get_and_parse_with_cache(path)
        return http_get(path) if @cache_timeout <= 0

        now = Time.now.to_i
        expired_at = now + @cache_timeout

        # Deleting all stale cache entries can be expensive. Do not do it every time
        periodically_clean_cache(now, expired_at) unless @cache_clean_interval == 0

        # Just refresh the entry being requested for performance
        unless @cache[path] && @cache[path][:created_at] < expired_at
          @cache[path] = {
            :created_at => now,
            :result => http_get_and_parse(path)
          }
        end
        @cache[path][:result]
      end

      def http_get_and_parse(path)
        httpreq = Net::HTTP::Get.new(path)

        if @config[:use_auth]
          httpreq.basic_auth @config[:auth_user], @config[:auth_pass]
        end

        begin
          httpres = @http.request(httpreq)
        rescue Exception => e
          Hiera.warn("[hiera-http]: Net::HTTP threw exception #{e.message}")
          raise Exception, e.message unless @config[:failure] == 'graceful'
          return
        end

        unless httpres.kind_of?(Net::HTTPSuccess)
          Hiera.debug("[hiera-http]: bad http response from #{@config[:host]}:#{@config[:port]}#{path}")
          Hiera.debug("HTTP response code was #{httpres.code}")
          unless httpres.code == '404' && @config[:ignore_404]
            raise Exception, 'Bad HTTP response' unless @config[:failure] == 'graceful'
          end
          return
        end

        parse_response httpres.body
      end


      def periodically_clean_cache(now, expired_at)
        return if now < @clean_cache_at.to_i

        @clean_cache_at = now + @cache_clean_interval
        @cache.delete_if do |_, entry|
          entry[:created_at] > expired_at
        end
      end
    end
  end
end


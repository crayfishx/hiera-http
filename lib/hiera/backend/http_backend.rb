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

        @regex_key_match = nil

        if confine_keys = @config[:confine_to_keys]
          confine_keys.map! { |r| Regexp.new(r) }
          @regex_key_match = Regexp.union(confine_keys)
        end


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

      def build_paths(key, scope, order_override)
        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        # Hiera don't support array as value for parse_string so we add it in config file.
        # Notes at https://docs.puppetlabs.com/hiera/1/variables.html#interpolation-tokens
        # We can't get the entire scope so we check if the value exist in the scope
        # and we try to resolve :paths with this value
        if !@config[:paths_array].nil?
          @config[:paths_array].map do |var, p|
            # if not in scope ignore it
            if !scope[var].nil?
              if scope[var].kind_of?(Array)
                scope[var].each do |v|
                  paths.push(Backend.parse_string(p, { var => v}, { 'key' => key }))
                end
              else
                # allow non array values too
                paths.push(Backend.parse_string(p, { var => scope[var]}, { 'key' => key }))
              end
            else
              Hiera.warn("[hiera-http]: Variable #{var} not in scope for path #{p}")
            end
          end
        end
        paths.insert(0, order_override) if order_override
        paths
      end

      def lookup(key, scope, order_override, resolution_type)

        # if confine_to_keys is configured, then only proceed if one of the
        # regexes matches the lookup key
        #
        if @regex_key_match
          return nil unless key[@regex_key_match] == key
        end

        answer = nil

        paths = build_paths(key, scope, order_override)

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
        YAML.load(answer)
      end

      def http_get_and_parse_with_cache(path)
        return http_get_and_parse(path) if @cache_timeout <= 0

        now = Time.now.to_i
        expired_at = now + @cache_timeout

        # Deleting all stale cache entries can be expensive. Do not do it every time
        periodically_clean_cache(now) unless @cache_clean_interval == 0

        # Just refresh the entry being requested for performance
        if !@cache[path] || @cache[path][:expired_at] < now
          @cache[path] = {
            :expired_at => expired_at,
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

        if @config[:headers]
          @config[:headers].each do |name,content|
            httpreq.add_field name.to_s, content
          end
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


      def periodically_clean_cache(now)
        return if now < @clean_cache_at.to_i

        @clean_cache_at = now + @cache_clean_interval
        @cache.delete_if do |_, entry|
          entry[:expired_at] < now
        end
      end
    end
  end
end



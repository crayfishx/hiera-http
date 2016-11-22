class Hiera
  module Backend
    class Http_backend

      def initialize
        require 'lookup_http'
        @config = Config[:http]

        lookup_supported_params = [
          :host,
          :port,
          :output,
          :failure,
          :ignore_404,
          :headers,
          :http_connect_timeout,
          :http_read_timeout,
          :use_ssl,
          :ssl_ca_cert,
          :ssl_cert,
          :ssl_key,
          :ssl_verify,
          :use_auth,
          :auth_user,
          :auth_pass,
        ]
        lookup_params = @config.select { |p| lookup_supported_params.include?(p) }

        @lookup = LookupHttp.new(lookup_params.merge( { :debug_log => "Hiera.debug" } ))


        @cache = {}
        @cache_timeout = @config[:cache_timeout] || 10
        @cache_clean_interval = @config[:cache_clean_interval] || 3600

      end

      def lookup(key, scope, order_override, resolution_type)

        require 'uri'

        # if confine_to_keys is configured, then only proceed if one of the
        # regexes matches the lookup key
        #
        if @regex_key_match
          return nil unless key[@regex_key_match] == key
        end


        answer = nil

        paths = @config[:paths].map { |p| Backend.parse_string(p, scope, { 'key' => key }) }
        paths.insert(0, order_override) if order_override


        paths.each do |path|

          Hiera.debug("[hiera-http]: Lookup #{key} from #{@config[:host]}:#{@config[:port]}#{path}")

          result = http_get_and_parse_with_cache(URI.escape(path))
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


      def http_get_and_parse_with_cache(path)
        return @lookup.get_parsed(path) if @cache_timeout <= 0

        now = Time.now.to_i
        expired_at = now + @cache_timeout

        # Deleting all stale cache entries can be expensive. Do not do it every time
        periodically_clean_cache(now) unless @cache_clean_interval == 0

        # Just refresh the entry being requested for performance
        if !@cache[path] || @cache[path][:expired_at] < now
          @cache[path] = {
            :expired_at => expired_at,
            :result => @lookup.get_parsed(path)
          }
        end
        @cache[path][:result]
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


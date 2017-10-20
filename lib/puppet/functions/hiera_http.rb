
Puppet::Functions.create_function(:hiera_http) do

  begin
    require 'lookup_http'
  rescue LoadError => e
    raise Puppet::DataBinding::LookupError, "Must install lookup_http gem to use hiera-http"
  end
  require 'uri'

  dispatch :lookup_key do
    param 'Variant[String, Numeric]', :key
    param 'Hash', :options
    param 'Puppet::LookupContext', :context
  end

  def lookup_key(key, options, context)

    if confine_keys = options['confine_to_keys']
      raise ArgumentError, 'confine_to_keys must be an array' unless confine_keys.is_a?(Array)
      confine_keys.map! { |r| Regexp.new(r) }
      regex_key_match = Regexp.union(confine_keys)
      unless key[regex_key_match] == key
        context.explain { "Skipping hiera_http backend because key does not match confine_to_keys" }
        context.not_found
        return
      end
    end

    options['uri'] = parse_tags(key, options['uri'])
    result = http_get(context, options)

    answer = return_answer(result, key, options)
    if answer == :not_found
      context.not_found
      return nil
    else
      return answer
    end

  end

  def return_answer(result, key, options)

    # dig defaults to true, dig_key defaults to the value of the 
    # lookup key.
    #
    dig = options.has_key?('dig') ? options['dig'] : true
    dig_key = options.has_key?('dig_key') ? options['dig_key'] : key

    # Interpolate values such as __KEY__ into each element of the
    # dig path, eg: dig_key: document.data.__MODULE__
    #
    dig_path = dig_key.split(/\./).map { |p| parse_tags(key, p) }


    if result.is_a?(String)
      return result
    else
      return dig ? hash_dig(result, dig_path) : result
    end

  end


  def hash_dig(data, dig_path)
    key = dig_path.shift
    if dig_path.empty?
      if data.has_key?(key)
        return data[key]
      else
        return :not_found
      end
    else
      return :not_found unless data[key].is_a?(Hash)
      return hash_dig(data[key], dig_path)
    end
  end

  def parse_tags(key,str)
    key_parts = key.split(/::/)

    parsed_str = str.gsub(/__(\w+)__/i) do
      case $1
      when 'KEY'
        key
      when 'MODULE'
        key_parts.first if key_parts.length > 1
      when 'CLASS'
        key_parts[0..-2].join('::') if key_parts.length > 1
      when 'PARAMETER'
        key_parts.last
      end
    end

    return parsed_str
  end



  def http_get(context, options)
    uri = URI.parse(options['uri'])
    host, port, path = uri.host, uri.port, URI.escape(context.interpolate(uri.request_uri))

    if context.cache_has_key(path)
      context.explain { "Returning cached value for #{path}" }
      return context.cached_value(path)
    else
      context.explain { "Querying #{uri}" }

      if context.cache_has_key('__lookuphttp')
        http_handler = context.cached_value('__lookuphttp')
      else
        lookup_params = {}
        options.each do |k,v|
          lookup_params[k.to_sym] = v if lookup_supported_params.include?(k.to_sym)
        end
        http_handler = LookupHttp.new(lookup_params.merge({:host => host, :port => port}))
        context.cache('__lookuphttp', http_handler)
      end

      begin
        response = http_handler.get_parsed(path)
        context.cache(path, response)
        return response
      rescue LookupHttp::LookupError => e
        raise Puppet::DataBinding::LookupError, "lookup_http failed #{e.message}"
      end
    end
  end

  def lookup_supported_params
    [
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
  end
end


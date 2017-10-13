
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

    json_key = key
    unless options['json_key'].nil?
      json_key = options['json_key']
      if json_key.respond_to?(:gsub)
        json_key = parse_tags(key, json_key)
      end
    end

    options['uri'] = parse_tags(key, options['uri'])
    result = http_get(context, options)

    answer = result.is_a?(Hash) && json_key != false ? result[json_key] : result
    context.not_found if answer.nil?
    return answer
  end

  def parse_tags(key,uri)
    key_parts = key.split(/::/)

    parsed_uri = uri.gsub(/__(\w+)__/i) do
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

    return parsed_uri
  end



  def http_get(context, options)
    uri = URI.parse(options['uri'])
    host, port, path = uri.host, uri.port, URI.escape(context.interpolate(uri.request_uri))

    if context.cache_has_key(path)
      context.explain { "Returning cached value for #{path}" }
      return context.cached_value(path)
    else
      context.explain { "Querying #{uri}" }
      lookup_params = {}
      options.each do |k,v|
        lookup_params[k.to_sym] = v if lookup_supported_params.include?(k.to_sym)
      end
      http_handler = LookupHttp.new(lookup_params.merge({:host => host, :port => port}))

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


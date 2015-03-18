## hiera_http : a HTTP back end for Hiera


### Description

This is a back end plugin for Hiera that allows lookup to be sourced from HTTP queries.  The intent is to make this backend adaptable to allow you to query any data stored in systems with a RESTful API such as CouchDB or even a custom store with a web front-end

### Configuration

The following is an example hiera.yaml configuration for use with hiera-http

    :backends:
      - http
     
    :http:
      :host: 127.0.0.1
      :port: 5984
      :output: json
      :cache_timeout: 10
      :failure: graceful
      :paths:
        - /configuration/%{fqdn}
        - /configuration/%{env}
        - /configuration/common


The following are optional configuration parameters

`:output: ` : Specify what handler to use for the output of the request.  Currently supported outputs are plain, which will just return the whole document, or YAML and JSON which parse the data and try to look up the key

`:http_connect_timeout: ` : Timeout in seconds for the HTTP connect (default 10)

`:http_read_timeout: ` : Timeout in seconds for waiting for a HTTP response (default 10)

`:cache_timeout: ` : Timeout in seconds for HTTP requests to a same path (default 10)

`:cache_clean_interval: ` : Interval (in secs) to clean the cache (default 3600), set to 0 to disable cache cleaning 

`:failure: ` : When set to `graceful` will stop hiera-http from throwing an exception in the event of a connection error, timeout or invalid HTTP response and move on.  Without this option set hiera-http will throw an exception in such circumstances

`:ignore_404: ` : If `failure` is _not_ set to `graceful` then any error code received from the HTTP response will throw an exception.  This option makes 404 responses exempt from exceptions.  This is useful if you expect to get 404's for data items not in a certain part of the hierarchy and need to fall back to the next level in the hierarchy, but you still want to bomb out on other errors.

The `:paths:` parameter can also parse the lookup key, eg:

    :paths:
      /configuration.php?lookup=%{key}

`:use_ssl:`: When set to true, enable SSL (default: false)

`:ssl_ca_cert`: Specify a CA cert for use with SSL

`:ssl_cert`: Specify location of SSL certificate

`:ssl_key`: Specify location of SSL key

`:ssl_verify`: Specify whether to verify SSL certificates (default: true)

`:use_auth:`: When set to true, enable basic auth (default: false)

`:auth_user:`: The user for basic auth

`:auth_pass:`: The password for basic auth

### TODO

Theres a few things still on my list that I'm going to be adding, including

* Add HTTP basic auth support
* Add proxy support
* Add further handlers (eg: XML)


### Author

* Craig Dunn <craig@craigdunn.org>
* @crayfishX
* IRC (freenode) crayfishx
* http://www.craigdunn.org

### Contributors

* SSL components contributed from Ben Ford <ben.ford@puppetlabs.com>
* Louis Jencka <jencka>

### Change Log

#### 1.2.0

* Support for SSL verify options <jencka>
* Support for HTTP auth <jencka>

#### 1.0.1

* 1.0 release
* Support for ignoring 404's when failure is not set to graceful
 
#### 0.1.0
* Stable
* Puppet Forge release

#### 0.0.2
* Added SSL support

#### 0.0.1
* Initial release



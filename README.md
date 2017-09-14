## hiera_http : a HTTP data provider function (backend) for Hiera 5

### Description

This is a back end function for Hiera 5 that allows lookup to be sourced from HTTP queries.  The intent is to make this backend adaptable to allow you to query any data stored in systems with a RESTful API such as CouchDB or even a custom store with a web front-end

### Compatibility

* The 3.x series of hiera-http is only compatible with Hiera 5, that ships with Puppet 4.9+
* Users looking for older implementations for Hiera 1,2 and 3 should use hiera-http 2.x
* hiera-http 3 ships within the [crayfishx/hiera_http](https://forge.puppet.com/crayfishx/hiera_http)
* hiera-http 2 (legacy) ships as a Rubygem "hiera-http"

### Requirements

The `lookup_http` gem must be installed and loadable from Puppet

```
# /opt/puppetlabs/puppet/bin/gem install lookup_http
# puppetserver gem install lookup_http
```


### Installation

The data provider is available by installing the `crayfishx/hiera_http` module into your environment.

```
# puppet module install crayfishx/hiera_http
```

### Configuration

See [The official Puppet documentation](https://docs.puppet.com/puppet/4.9/hiera_intro.html) for more details on configuring Hiera 5.

The following is an example Hiera 5 hiera.yaml configuration for use with hiera-http

```yaml
---

version: 5

hierarchy:
  - name: "Hiera-HTTP lookup"
    lookup_key: hiera_http
    uris:
      - http://localhost:5984/host/%{trusted.certname}
      - http://localhost:5984/dc/%{facts.location}
      - http://localhost:5984/role/%{facts.role}
    options:
      output: json
      ignore_404: true
```

The following mandatory Hiera 5 options must be set for each level of the hierarchy.

`name`: A human readable name for the lookup
`lookup_key`: This option must be set to `hiera_http`
`uris` or `uri`: An array of URI's passed to `uris` _or_ a single URI passed to `uri`


The following are optional configuration parameters supported in the `options` hash of the Hiera 5 config

`:output: ` : Specify what handler to use for the output of the request.  Currently supported outputs are plain, which will just return the whole document, or YAML and JSON which parse the data and try to look up the key

`:http_connect_timeout: ` : Timeout in seconds for the HTTP connect (default 10)

`:http_read_timeout: ` : Timeout in seconds for waiting for a HTTP response (default 10)

`:confine_to_keys: ` : Only use this backend if the key matches one of the regexes in the array

      confine_to_keys:
        - "application.*"
        - "apache::.*"

`:failure: ` : When set to `graceful` will stop hiera-http from throwing an exception in the event of a connection error, timeout or invalid HTTP response and move on.  Without this option set hiera-http will throw an exception in such circumstances

`:ignore_404: ` : If `failure` is _not_ set to `graceful` then any error code received from the HTTP response will throw an exception.  This option makes 404 responses exempt from exceptions.  This is useful if you expect to get 404's for data items not in a certain part of the hierarchy and need to fall back to the next level in the hierarchy, but you still want to bomb out on other errors.

`:use_ssl:`: When set to true, enable SSL (default: false)

`:ssl_ca_cert`: Specify a CA cert for use with SSL

`:ssl_cert`: Specify location of SSL certificate

`:ssl_key`: Specify location of SSL key

`:ssl_verify`: Specify whether to verify SSL certificates (default: true)

`:use_auth:`: When set to true, enable basic auth (default: false)

`:auth_user:`: The user for basic auth

`:auth_pass:`: The password for basic auth

`:headers:`: Hash of headers to send in the request

### Using the key name as part of the URI

Previous versions of this backed allowed the use of `%{key}` to include the key
name as part of the URL. Due to API changes in Hiera v5, this interpolation is
no longer possible. This backend now supports an alternative method to include
the key name using the `__KEY__` tag.

Example using this backend to interact with the [Puppet Enterprise Jenkins Pipeline plugin](https://wiki.jenkins.io/display/JENKINS/Puppet+Enterprise+Pipeline+Plugin)

```yaml
---
version: 5

defaults:
  datadir: hieradata
  data_hash: yaml_data

hierarchy:
  - name: 'Jenkins data source'
    lookup_key: hiera_http
    uris:
      - "http://jenkins.example.com:8080/hiera/lookup?scope=%{::trusted.certname}&key=__KEY__"
      - "http://jenkins.example.com:8080/hiera/lookup?scope=%{::environment}&key=__KEY__"
    options:
      output: json
      failure: graceful
#      use_auth: true
#     auth_user: ''
#     auth_pass: ''

```

### Author

* Craig Dunn <craig@craigdunn.org>
* @crayfishX
* IRC (freenode) crayfishx
* http://www.craigdunn.org



[![Build Status](https://travis-ci.org/crayfishx/hiera-http.svg?branch=master)](https://travis-ci.org/crayfishx/hiera-http)

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
`uris` or `uri`: An array of URI's passed to `uris` _or_ a single URI passed to `uri`. This option supports interpolating special tags, see below.


The following are optional configuration parameters supported in the `options` hash of the Hiera 5 config

#### Lookup options

`output: ` : Specify what handler to use for the output of the request.  Currently supported outputs are plain, which will just return the whole document, or YAML and JSON which parse the data and try to look up the key

`http_connect_timeout: ` : Timeout in seconds for the HTTP connect (default 10)

`http_read_timeout: ` : Timeout in seconds for waiting for a HTTP response (default 10)

`confine_to_keys: ` : Only use this backend if the key matches one of the regexes in the array

      confine_to_keys:
        - "application.*"
        - "apache::.*"

`failure: ` : When set to `graceful` will stop hiera-http from throwing an exception in the event of a connection error, timeout or invalid HTTP response and move on.  Without this option set hiera-http will throw an exception in such circumstances

`ignore_404: ` : If `failure` is _not_ set to `graceful` then any error code received from the HTTP response will throw an exception.  This option makes 404 responses exempt from exceptions.  This is useful if you expect to get 404's for data items not in a certain part of the hierarchy and need to fall back to the next level in the hierarchy, but you still want to bomb out on other errors.

`dig:` : (true or false)  When the output is parsed YAML or JSON, whether or not to dig into the hash and return the value defined by the `dig_key` option below.  This option defaults to `true`

`dig_key` : When the `dig` option is true (default), this option specifies what key is looked up from the results hash returned by the HTTP endpoint.  See [Digging values](#digging-values) below for more information

#### HTTP options

`use_ssl:`: When set to true, enable SSL (default: false)

`ssl_ca_cert`: Specify a CA cert for use with SSL

`ssl_cert`: Specify location of SSL certificate

`ssl_key`: Specify location of SSL key

`ssl_verify`: Specify whether to verify SSL certificates (default: true)

`use_auth:`: When set to true, enable basic auth (default: false)

`auth_user:`: The user for basic auth

`auth_pass:`: The password for basic auth

`headers:`: Hash of headers to send in the request

#### eyaml support

`eyaml:`: When set to true, enable eyaml support (default: false)

`eyaml_options`: Specify a eyaml options

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
      eyaml: true
      eyaml_options:
        pkcs7_private_key: /etc/puppetlabs/puppet/keys/private_key.pkcs7.pem
        pkcs7_public_key: /etc/puppetlabs/puppet/keys/public_key.pkcs7.pem
```

### Interpolating special tags

Previous versions of this backed allowed the use of variables such as `%{key}` and `%{calling_module}` to be used in the URL, this has changed with Hiera 5. To allow for similar behaviour you can use a number of tags surrounded by `__` to interpolate special variables derived from the key into the `uri` or `uris` option in hiera.yaml. Currently you can interpolate `__KEY__`, `__MODULE__`, `__CLASS__` and `__PARAMETER__`, these tags are derived from parsing the original lookup key.

In the case of a lookup key matching `foo::bar::tango` the following tags are available;

* `__KEY__` : The original lookup key unchanched; `foo::bar::tango`
* `__MODULE__` : The first part of the lookup key; `foo`
* `__CLASS__` : All but the last parts of the lookup key; `foo::bar`
* `__PARAMETER__` : The last part of they key representing the class parameter; `tango`

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
      - "http://jenkins.example.com:8080/hiera/lookup?scope=%{trusted.certname}&key=__KEY__"
      - "http://jenkins.example.com:8080/hiera/lookup?scope=%{environment}&key=__KEY__"
    options:
      output: json
      failure: graceful
```

### Digging values

Hiera-HTTP supports options to automatically dig into the returned data structure to find a corresponding key.  Puppet lookup itself supports similar dig functionality but being able to specify it at the backend means that where an API wraps the required data up in a different way, we can always lookup the desired value before passing it to Puppet to ensure that class parameter lookups work without having to hard code the `lookup` function and dig down into the data for each request.   The dig functionality in Puppet is intended to enable you to parse your data more effectivly, the dig functionality in hiera-http is intended to make the API of the endpoint you are talking to compatible.

By default, when a hash is returned by the HTTP endpoint (eg: JSON) then hiera-http will attempt to lookup the key corresponding with the lookup key.  For example, when looking up a key `apache::port` we would expect the HTTP endpoint to return something like;

```json
{
  "apache::port": 80
}
```

Returned value would be `80`

Depending on what HTTP endpoint we are hitting, the returned output may contain other data with the key that we want to look up nested below it. This behaviour can be overriden by using the options `dig` and `dig_key`.

The `dig_key` option can be used to change the key that is looked up, it also supports a dot-notation for digging values in nested hashes. [Special tags](#interpolating-special-tags) can also be used in the `dig_key` option.  Consider the following example output from our HTTP endpoint;

```json
{
  "document": {
    "settings": {
      "apache::port": 80
    }
  }
}
```


In this scenario we wouldn't be able to use class parameter lookups out-of-the-box, even if we just returned the whole structure, because we always need to drill down into `document.settings` to get the correct value, so In order to map the lookup to find the correct value, we can interpolate the __KEY__ tag into `lookup_key` and tell hiera-http to always dig into the hash with the following option;

```yaml
  options:
    dig_key: document.settings.__KEY__
```

A more complicated example;

```json
{
  "document": {
    "settings": {
      "apache": {
        "port": 80
      }
    }
  }
}
```

Can be looked up with;

```
  options:
    dig_key: document.settings.__MODULE__.__PARAMETER__
```

In both examples, the returned value to Puppet will be `80`

### Returning the entire data structure

The `dig` option can be used to disable digging altogether and the entire data hash will be returned with no attempt to resolve a key



### Author

* Craig Dunn <craig@craigdunn.org>
* @crayfishX
* IRC (freenode) crayfishx
* http://www.craigdunn.org



## 3.3.1  (3.3.0 pulled due to forge package error)

* Feature: New parameters `dig` and `dig_value` give greater control over dealing with APIs that return data in different formats by allowing hiera-http to dig down into the returned data hash to find the corresponding key. Read more about this feature [in the documentation](https://github.com/crayfishx/hiera-http#digging-values)   (https://github.com/crayfishx/hiera-http/pull/66)

* Enhnacement: Hiera-HTTP can now distinguish between a nil value and an undefined value.  If a hash contains the key for the lookup with no data, this is assumed to be a key set to nil and is returned to Hiera as nil.  Where there is no key found this is assumed to be undefined and the `context.not_found()` method of Hiera is called.  This allows data to contain keys explicitly set to nil.

* Enhancement: Better caching of the lookuphttp object in between requests.


## 3.2.0

* Feature: Added the tags `__MODULE__`, `__PARAMETER__` and `__CLASS__` for URL interpolation
* Bugfix: lookup_http was still being called even when Hiera had a cached value for the lookup path

## 3.1.0

* Fix: Hiera 5 no longer allows us to pass `%{key}` through from the configuration to be interpolated by the backend, as was documented examples for hiera-http 2.x - to get around this issue the keyword `__KEY__` can be used in URI paths to interpolate the key into the URL (https://github.com/crayfishx/hiera-http/pull/53)

* Fix: URI Escaping of paths with parameters (&foo=bar) caused the parameters to be dropped (https://github.com/crayfishx/hiera-http/pull/53) this has now been fixed.


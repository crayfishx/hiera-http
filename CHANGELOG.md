
## 3.1.0

* Fix: Hiera 5 no longer allows us to pass `%{key}` through from the configuration to be interpolated by the backend, as was documented examples for hiera-http 2.x - to get around this issue the keyword `__KEY__` can be used in URI paths to interpolate the key into the URL (https://github.com/crayfishx/hiera-http/pull/53)

* Fix: URI Escaping of paths with parameters (&foo=bar) caused the parameters to be dropped (https://github.com/crayfishx/hiera-http/pull/53) this has now been fixed.


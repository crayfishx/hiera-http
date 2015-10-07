require 'rubygems'
require 'rubygems/package_task'

spec = Gem::Specification.new do |gem|
    gem.name = "hiera-http"
    gem.version = "2.0.0"
    gem.summary = "HTTP backend for Hiera"
    gem.email = "craig@craigdunn.org"
    gem.author = "Craig Dunn"
    gem.homepage = "http://github.com/crayfishx/hiera-http"
    gem.description = "Hiera backend for looking up data over HTTP APIs"
    gem.require_path = "lib"
    gem.files = FileList["lib/**/*"].to_a
    gem.add_dependency('json', '>=1.1.1')
    gem.add_dependency('lookup_http', '>=1.0.0')
end

Gem::PackageTask.new(spec) do |pkg|
    pkg.need_tar = true
    pkg.gem_spec = spec
end

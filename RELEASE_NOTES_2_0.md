# Release notes 2.0 #

## Introduction ##

### Dude, wheres my code? ###

Recently I have been talking about a new, very young tool called [Jerakia](http://github.com/crayfishx/jerakia) which can be used along side of, or in place of Hiera.  Part of the Jerakia roadmap was adding an HTTP datasource and it would have meant a lot of wheel re-inventing to implement since hiera-http had all the HTTP specific stuff built in.  The HTTP components of hiera-http have been farmed out to [lookup_http](http://github.com/crayfishx/lookup_http) and hiera-http implements the lookup_http methods for the HTTP side of things meaning that other tools (such as Jerakia) can also use the library.

Despite being a 2.0 release, there should be no breaking changes if packages are installed using gem and the lookup_http gem is instaled as a dependancy.








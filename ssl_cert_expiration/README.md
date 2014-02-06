SSL Cert Expiration Plugin
=====================
Created by Patrick O'Brien

Compatibility 
-------------
Requires [Ruby Standard Library: openssl](http://ruby-doc.org/stdlib-1.9.3/libdoc/openssl/rdoc/), which is included in the Ruby Standard Library.

Functionality
-------------
Returns the number of days from check execution until SSL cert expiration. This is a different approach than the existing [ssl_monitor](https://github.com/scoutapp/scout-plugins/tree/master/ssl_monitor) plugin which assumes the SSL certificate will be available via http/https. This requires the SSL cert to be available on the node's filesystem and readable by whatever user scout is running as.


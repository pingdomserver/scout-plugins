Cloudkick Plugin Wrapper
========================
Created by [cognita](http://github.com/cognita)

Overview
--------

This plugin can run any Cloudkick monitoring plugin and report the metrics to Scout. The Cloudkick plugin status is reported in the metric "Status" (0 for ok, 1 for warn/err).

Configuration
-------------

The `cloudkick_plugin` option contains the file name of the Cloudkick plugin you want to run (it looks for a file in `/usr/lib/cloudkick-agent/plugins` if you do not enter an absolute path).

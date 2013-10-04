# Unicorn Watcher
===============

Scout plugin to monitor when a unicorn master goes down. Checks for the expected pid and process name which are specified in the configuration options for this plugin within Scout.

Disclaimer: I sort of moonlight as a DevOps type so please do submit a Pull Request or at least file an issue if something you see here could be done better. 

## Current Version
1.0.0

## Requirements

* [Scout](https://scoutapp.com/)
* A valid PID to check for your unicorn master. 

## Installation
Same as any other Scout plugin. You can install it from within Scout or by manually placing unicorn_watch.rb on your server in /home/USER_RUNNING_SCOUT/.scout/
Here are a few links with more details about creating and installing Scout plugins
* [Creating a plugin](https://scoutapp.com/info/creating_a_plugin)
* [Scout help](https://scoutapp.com/help)

## Usage Instructions

Install plugin. Be sure to configure it within the Scout GUI so that it checks for the correct PID and process name. Then customize alerts in Scout to your liking so you are notified when the unicorn master goes away. 

## Configuration Examples
There are really only two options to be configured within Scout for this plugin

1. The location of the PID file for your Unicorn master process. The location of this file is entirely dependent on how you have configured your startup scripts. 
That said, the [Unicorn docs](http://unicorn.bogomips.org/) state that
_"By default, unicorn_rails(1) will create a PID file in "RAILS_ROOT/tmp/pids/unicorn.pid". You may override this by specifying the "pid" directive to override this Unicorn config file."_
2. The Unicorn master process_name. Typically unicorn master or unicorn_master. Do a 
   ```bash
     ps aux|grep unicorn
   ```
  to see what yours is called.

## Authors

* Chris Stringer / [@jcstringer](https://github.com/jcstringer)

## Contributions

1. Fork it
2. Get it running (see Installation above)
3. Create your feature branch (`git checkout -b my-new-feature`)
4. Write your code and **specs**
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create new Pull Request

If you find bugs, have feature requests or questions, please
[file an issue](https://github.com/jcstringer/unicorn-watcher/issues).

### Specs
Tests are run using test/unit and require the mocha gem for stubbing. 

```bash
ruby test.rb
```

## License

Copyright (c) 2013 Chris Stringer

MIT License

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

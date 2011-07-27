Scout Plugins Library
=====================

[Scout](http://scoutapp.com) is a hosted monitoring solution. Scout uses open-source plugins (written in Ruby)
to monitor a wide variety of system, OS, and application metrics.

Each folder in this repository represents one Scout plugin.

Gem Dependencies 
----------------

This repo contains a Gemfile to use with bunder to install needed Gems for tests and the plugins themselves. 

If you don't have Bundler:

    gem install bundler

Once Bundler is installed:

    bundle install

How to Make your own Scout plugin
---------------------------------

Anyone can create a Scout plugin. Get started by:

1. looking at the examples in this Repository
2. reading the development guide at http://scoutapp.com/info/creating_a_plugin

When you have something working you'd like to share, drop us a note at <support@scoutapp.com>.

Or, send us a pull request here on github. Also don't hesitate to contact us before or during
plugin development if you need guidance.


A note on tests
---------------

Plugin tests are key. Read up on plugin testing at http://scoutapp.com/info/creating_a_plugin#test_file.

We prefer test/unit for its ubiquity and simplicity. 

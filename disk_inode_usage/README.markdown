Disk Inode Usage
================

A plugin for tracking inode usage. This is most useful for those times when you get `No space left on device` errors, but `df -h` shows plenty of space. In those cases, it's usually a matter of running out of inodes


Triggers
--------

This plugin comes with one trigger enabled out of the box. It triggers when inode used % hits 85%. When that goes off, it's times to start digging into what's using up all the inodes. See Resources below for some tips and further reading.

Resources
---------

 * [No space left on device - running out of inodes](http://www.ivankuznetsov.com/2010/02/no-space-left-on-device-running-out-of-inodes.html)

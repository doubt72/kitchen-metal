# kitchen-metal

Kitchen::Metal - a Metal driver for Test Kitchn

This is a gem that allows kitchen to execute metal recipes directly to define
machines and topologies for testing.

## Requirements

Requires Chef Metal and Test Kitchen.

## Installation

Installation is fairly easy, simply run the following commands in the main directory here:

```
gem build kitchen-metal.gemspec
gem install ./kitchen-metal-<version>.dev.gem 
```

## Notes

Still working on it.  More stuff later.

## Authors

Created mainly by Douglas Triggs <doug@getchef.com> with help from John Keiser
<jkeiser@getchef.com> based on the structure of the kitchen-vagrant driver written
by Fletcher Nichol <fnichol@nichol.ca> with a brief stop along the way in the form
of the kitchen-vagrant-metal driver.

# kitchen-metal

Kitchen::Metal - a Metal driver for Test Kitchn

This is a gem that allows kitchen to execute metal recipes directly to define
machines and topologies for testing.

## Requirements

Requires Chef Metal and Test Kitchen.  Also a properly configured busser installed
(separately) to get localhost (local observer) tests running properly (i.e., the
busser gem plus plugins and and such).

## Installation

Installation is fairly easy, simply run the following commands in the main directory
here:

    gem build kitchen-metal.gemspec
    gem install ./kitchen-metal-<version>.dev.gem

The gem requires the test-kitchen and chef-metal gems to run.  Note, however, that
you may need forks or branches of those gems to get the driver working properly [as
of this writing, chef-metal master should be fine, but you'll need to use my fork of
test-kitchen, metal-support branch. Also cheffish, but hopefully that will be PR'd, reviewed, and merged into master soon -- doubt72].

## Setting Up Kitchen-Metal

This is the metal kitchen driver; unlike other kitchen drivers, it supports
arbitrary topologies (essentially, it supports whatever metal supports).

The .kitchen.yml is largely organized like other .kitchen.yml files, but there are
some notable differences.  The first major difference is the layout in the driver
parameters.  This is a metal recipe; it's intended to be a list of machines (i.e.,
the layout or topology of the system to be tested).  It could be anything from a
single machine to an arbitrary set of clusters, i.e., anything metal can support.
As this might seem to imply, it also doesn't have to be a topology at all, or it
could include much more than just the topology; again, it can specify anything a
metal recipe could specify (see [Chef Metal](https://github.com/opscode/chef-metal)
for more information on chef-metal recipes).

    driver:
      name: metal
      layout: layout.rb

Right now, the layout recipe is found in the kitchen root directory (i.e., the same
directory that contains the .kitchen.yml file).  In the future, it's likely this may
change.

The second major difference is that when using the kitchen-metal driver, it requires
the use of the chef_metal provisioner.  This is not a true provisioner (metal
handles all of its own provisioning and specifications for its own provisioning),
but is required so that the metal driver can access various configuration parameters.

    provisioner:
      name: chef_metal

This provisioner is currently only available in a fork/branch of Test Kitchen at the
moment I write this.  This may or may not go away as we test kitchen gets refactored
to better integrate with Chef Metal; like this driver, this is fairly expirimental.

The next major difference is that the platform name has been replaced with another
metal recipe.  This recipe is essentially combined with the layout recipe.  This
recipe is intended to be used to specify the platform parameters, but like the
layout recipe, it can be any valid metal recipe.  Again, this recipe is found in the
kitchen root; again this may (probably will) change in the future.

    platforms:
      - name: platform.rb

The final major difference is the addition of the "nodes" parameter in the suite.
This specifies all of the nodes to run tests on (tests will also be run on the host
running test kitchen if they exist and busser is configured correctly).  See
"Running Tests" below for more about this.

    suites:
      - name: default
        nodes: [spyder, fly]

This configuration will also likely change in the future; see "Possible Future
Changes" below.

##  Running Tests

The tests for the kitchen-metal driver are more or less in the same place as they've
always been, i.e., under the same path:

    <kitchen_root>/test/integration

However, the way they're organized is slightly different.  Tests can still be put in the suite-level path:

    <kitchen_root>/test/integration/<suite_name>

...But these tests will be run on the host system (as observer tests) if they exist.
They are still run with busser, but it currently requires you to manually install
and configure busser yourself (i.e., install the busser gem, plugins, etc).
Theoretically, anyway, I have not gotten busser tests to run properly on my own
local machine.  So, it's possibly that this simply won't ever work for whatever
reason (in which case you could still probably set up an observer node and run tests
on it).

Tests for each of the nodes (as specified by the "nodes" parameter in the suite in
the .kitchen.yml) install and run on those nodes (i.e., the machines with the same
name as the nodes).  Those files go in directories like this:

    <kitchen_root>/test/integration/<node_name>/<suite_name>

For other limitations, see "Things That Are Broke" below.

## Probable Future Changes

This cannot be emphasised enough: this is an experimental driver.  It will change.
It's configuration and setup will change.  Probably radically.

Specifically, a better method of specifying nodes will probably exist at some point.
That will allow a more configurable way of specifying test paths (since right now,
the suite name cannot match any of the node names, nor can multiple nodes share the
same tests without hacking your own soft links and such).  As we work on integrating
metal and test kitchen, there will no doubt be some other changes as well.  We might
remove the .rb from platforms and add it during runtime.  We might move the layout
and platform recipes somewhere other than kitchen root.  And likely there will be
other changes that we can't currently predict.

## Things That Are Broke

At this point, there are a couple issues with the driver as it stands; there may be
other issues we don't actually know about, but then, we don't know about them.

1. Windows probably won't work with busser as is.  This isn't tested, though.

2. We haven't gotten busser working locally.  Theoretically it should work, but
essentially it's untested.

## Authors

Created mainly by Douglas Triggs <doug@getchef.com> with help from John Keiser
<jkeiser@getchef.com> based on the structure of the kitchen-vagrant driver written
by Fletcher Nichol <fnichol@nichol.ca> with a brief stop along the way in the form
of the kitchen-vagrant-metal driver.

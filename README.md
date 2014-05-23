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
currently this needs the dt/metal-support branch on the [doubt72 fork of
test-kitchen](https://github.com/doubt72/test-kitchen) to run properly.

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
      layout: layout

The layout file (actually called layout.rb in this case) should be put in the
recipes directory of the kitchen project you are working on.

The second major difference is that when using the kitchen-metal driver, no
provisioner is required (metal does its own provisioning) and in fact that parameter
is simply ignored, so you can leave it out completely.

The next major difference is that the platform name has been replaced with another
metal recipe.  This recipe is essentially combined with the layout recipe.  This
recipe is intended to be used to specify the platform parameters, but like the
layout recipe, it can be any valid metal recipe.  Again, this recipe is found in the
recipes directory of your project (and should be a ruby file, and have ".rb"
appended to the name).

    platforms:
      - name: platform

The final major difference is the addition of the "nodes" parameter in the suite.
This specifies all of the nodes to run tests on (tests will also be run on the host
running test kitchen if they exist and busser is configured correctly).  See
"Running Tests" below for more about this.

    nodes:
      - name: default

This configuration will also likely change in the future; see "Possible Future
Changes" below.

Here is an example of a simple (but fully functional) .kitchen.yml file (assuming
you have a layout.rb, platform.rb and platform2.rb file in your recipes dir):

    ---
    driver:
      name: metal
      layout: layout

    platforms:
      - name: platform
      - name: platform2

    suites:
      - name: default
        attributes:

    nodes:
      - name: spyder
      - name: fly

##  Running Tests

By default, the tests for the kitchen-metal driver are more or less in the same
place as they've always been, i.e., under the same path:

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
name as the nodes).  By default, those files go in directories like this:

    <kitchen_root>/test/integration/<node_name>/<suite_name>

However, just as you can specify the test path in the suites, you can also use
whatever path you like for each node; this way nodes could even share test paths if
that made sense for whatever reason.

## Probable Future Changes

This cannot be emphasised enough: this is an experimental driver.  It will change.
It may even go away completely and/or be absorved into test-kitchen itself in a more
general way.  At this point, it's not certain what those changes may look like, though.

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

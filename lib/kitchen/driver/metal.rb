# -*- encoding: utf-8 -*-
#
# Author:: Douglas Triggs (<doug@getchef.com>), John Keiser (<jkeiser@getchef.com>)
#
# Copyright (C) 2014, Chef Software, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/node'
require 'chef/run_context'
require 'chef/event_dispatch/dispatcher'
require 'chef/recipe'
require 'chef/runner'
require 'chef/formatters/doc'

require 'chef_metal'
require 'chef/providers'
require 'chef/resources'

require 'kitchen/action_handler'

require 'kitchen/driver/metal_helper'
require 'rspec'
require 'rspec/core/formatters/documentation_formatter'

module Kitchen
  module Driver

    # Metal driver for Kitchen. Using Metal recipes for great justice.
    #
    # @author Douglas Triggs <doug@getchef.com>
    #
    # This structure is based on (read: shamelessly stolen from) the generic kitchen
    # vagrant driver written by Fletcher Nichol and modified for our nefarious
    # purposes.

    class Metal < Kitchen::Driver::Base
      default_config :transport, :ssh

      def create(state)
        run_pre_create_command
        run_recipe(state)
        info("Vagrant instance #{instance.to_str} created.")
      end

      def converge(state)
        run_recipe(state)
      end

      def setup(state)
        run_recipe(state)
        target = instance.provisioner.config[:node]
        if (target)
          # If there's no target, there's no point in running setup, since we don't
          # have a machine we need to prep for anything; we'll be running tests
          # external to all our VMs
          run_setup(state, target)
        end
      end

      def verify(state)
        run_recipe(state)
        run_tests(state, instance.provisioner.config[:node])
      end

      def destroy(state)
        run_destroy(state)
        info("Vagrant instance #{instance.to_str} destroyed.")
      end

#      def login_command(state)
#        SSH.new(*build_ssh_args(state)).login_command
#      end

#      def ssh(ssh_args, command)
#        Kitchen::SSH.new(*ssh_args) do |conn|
#          run_remote(command, conn)
#        end
#      end

      protected

      # This gets the high-level recipe from driver/layout in the .kitchen.yml;
      # this is more or less intended for setting up the layout/machines,
      # etc. but you can ultimately use it however you like
      def get_driver_recipe
        # TODO: we may want to move the path from the top level
        return nil if config[:layout].nil?
        path = "#{config[:kitchen_root]}/#{config[:layout]}"
        file = File.open(path, "rb")
        contents = file.read
        file.close
        contents
      end

      # This gets the high-level recipe from platform/name in the .kitchen.yml;
      # this is more or less intended for setting up the platform/environment,
      # etc. but you can ultimately use it however you like
      def get_platform_recipe
        # TODO: we may want to move the path from the top level
        path = "#{config[:kitchen_root]}/#{instance.platform.name}"
        file = File.open(path, "rb")
        contents = file.read
        file.close
        contents
      end

      # This is used to converge our metal recipes
      def run_recipe(state)
        # Don't run this again if we've already converged it
        return if @environment_created

        # Set up our enviroment so we can run this in place
        node = Chef::Node.new
        node.name 'nothing'
        node.automatic[:platform] = 'kitchen_metal'
        node.automatic[:platform_version] = 'kitchen_metal'
        Chef::Config.local_mode = true
        run_context = Chef::RunContext.new(node, {},
          Chef::EventDispatch::Dispatcher.new(Chef::Formatters::Doc.new(STDOUT,STDERR)))
        recipe_exec = Chef::Recipe.new('kitchen_vagrant_metal',
          'kitchen_vagrant_metal', run_context)

        # We require a platform, but layout in driver is optional
        recipe_exec.instance_eval get_platform_recipe
        recipe = get_driver_recipe
        recipe_exec.instance_eval recipe if recipe
        Chef::Runner.new(run_context).converge

        # Grab the machines so we can save them for later (i.e., for login/to destroy
        # them/etc.)  We have to be careful of duplicate nodes with the same name and
        # that we're actually getting machine resource names
        machines = []
        run_context.resource_collection.each do |resource|
          if (resource.is_a?(Chef::Resource::Machine))
            if (!machines.include?(resource.name))
              machines.push(resource.name)
            end
          end
        end
        state[:machines] = machines
        @environment_created = true
      end

      # This is used to get a node with a specific name
      def get_node(state, name)
        machines = state[:machines]
        if (machines.include?(name))
          chef_server = Cheffish::CheffishServerAPI.new(Cheffish.enclosing_chef_server)
          nodes = chef_server.get("/nodes")
          node_url = nodes[name]
          chef_server.get(node_url)
        else
          nil
        end
      end

      # This is used to get all our machine nodes
      def get_all_nodes(state)
        rc = []
        machines = state[:machines]
        chef_server = Cheffish::CheffishServerAPI.new(Cheffish.enclosing_chef_server)
        nodes = chef_server.get("/nodes")
        nodes.each_key do |key|
          if (machines.include?(key))
            node_url = nodes[key]
            node = chef_server.get(node_url)
            rc.push(node)
          end
        end
        return rc
      end

      # This is used to prep machines for the verify stage; this is only needed when
      # we're running tests on a particular machine (i.e., when a node name is
      # supplied in .kitchen.yml)
      def run_setup(state, target)
        machines = state[:machines]
        raise ClientError, "No machine with name #{target} exists, cannot setup test " +
          "suite as specified by .kitchen.yml" if !machines.include?(target)
        node = get_node(state, target)
        provisioner = ChefMetal.provisioner_for_node(node)
        # TODO: need to change test_base_path in busser for this to ever work
        transport = provisioner.transport_for(node)
        transport.execute(busser_setup_cmd)
      end

      # This is used to run tests.  If we have a node name supplied in .kitchen.yml,
      # we run on that machine, otherwise we run an external rspec suite
      def run_tests(state, target)
        if (target.nil?)
          # We don't have a node (i.e., no target) so run the external tests

          # Add machine objects for easy reference in rspec;
          # These are accessed by MetalHelper.<machine name> and have the following
          # methods:
          #   name        : machine/node name
          #   hostname    : machine hostname
          #   fqdn        : fully qualified domain name
          #   ipaddress   : IP address
          #   ipv6address : IPV6 address
          nodes = get_all_nodes(state)
          nodes.each do |node|
            MetalHelper.add_machine(node)
          end

          # NOTE: we only support rspec at this time, so will need to use the
          # standard spec dir for it to find the tests
          path = "#{config[:test_base_path]}/#{instance.suite.name}/spec"
          rspec_config = RSpec.configuration
          rspec_config.color = true
          formatter = RSpec::Core::Formatters::DocumentationFormatter.new(rspec_config.output)
          reporter =  RSpec::Core::Reporter.new(formatter)
          rspec_config.instance_variable_set(:@reporter, reporter)
          files = []
          Dir.glob("#{path}/*") do |filename|
            files.push(filename)
          end

          # Run the things!  Report the outputs!
          RSpec::Core::Runner.run(files)
          puts formatter.output.string
        else
          # We do have a node (i.e., a target) so we run on that host
          machines = state[:machines]
          raise ClientError, "No machine with name #{target} exists, cannot run test " +
            "suite as specified by .kitchen.yml" if !machines.include?(target)
          node = get_node(state, target)
          provisioner = ChefMetal.provisioner_for_node(node)
          transport = provisioner.transport_for(node)

          # TODO: need to change test_base_path in busser for this to ever work
          transport.execute(busser_sync_cmd)
          transport.execute(busser_run_cmd)
        end
      end

      # Destroy all the things!
      def run_destroy(state)
        # TODO: fix it so it actually works without this; right now, has pem issues
        # when not run as full "kitchen test" run
        return if !@environment_created
        # TODO: test this out of band, i.e., run setup then run destroy instead of test
        return if !state[:machines] || state[:machines].size == 0
        nodes = get_all_nodes(state)
        nodes.each do |node|
          provisioner = ChefMetal.provisioner_for_node(node)
          provisioner.delete_machine(Kitchen::ActionHandler.new("test_kitchen"), node)
        end
        state[:machines] = []
        @environment_created = false
      end

#      def build_ssh_args(state)
#        combined = config.to_hash.merge(state)

#        opts = Hash.new
#        opts[:user_known_hosts_file] = "/dev/null"
#        opts[:paranoid] = false
#        opts[:keys_only] = true if combined[:ssh_key]
#        opts[:password] = combined[:password] if combined[:password]
#        opts[:forward_agent] = combined[:forward_agent] if combined.key? :forward_agent
#        opts[:port] = combined[:port] if combined[:port]
#        opts[:keys] = Array(combined[:ssh_key]) if combined[:ssh_key]
#        opts[:logger] = logger

#        [combined[:hostname], combined[:username], opts]
#      end

#      def env_cmd(cmd)
#        env = "env"
#        env << " http_proxy=#{config[:http_proxy]}"   if config[:http_proxy]
#        env << " https_proxy=#{config[:https_proxy]}" if config[:https_proxy]

#        env == "env" ? cmd : "#{env} #{cmd}"
#      end

#      def run_remote(command, connection)
#        return if command.nil?

#        connection.exec(env_cmd(command))
#      rescue SSHFailed, Net::SSH::Exception => ex
#        raise ActionFailed, ex.message
#      end

#      def transfer_path(locals, remote, connection)
#        return if locals.nil? || Array(locals).empty?

#        info("Transferring files to #{instance.to_str}")
#        locals.each { |local| connection.upload_path!(local, remote) }
#        debug("Transfer complete")
#      rescue SSHFailed, Net::SSH::Exception => ex
#        raise ActionFailed, ex.message
#      end

#      def wait_for_sshd(hostname, username = nil, options = {})
#        SSH.new(hostname, username, { :logger => logger }.merge(options)).wait
#      end

      def run(cmd, options = {})
        cmd = "echo #{cmd}" if config[:dry_run]
        run_command(cmd, { :cwd => config[:kitchen_root] }.merge(options))
      end

      def run_pre_create_command
        if config[:pre_create_command]
          run(config[:pre_create_command], :cwd => config[:kitchen_root])
        end
      end
    end
  end
end

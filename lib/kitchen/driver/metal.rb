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

module Kitchen
  module Driver

    # Metal driver for Kitchen. Using Metal recipes for great justice.
    #
    # @author Douglas Triggs <doug@getchef.com>
    #
    # This structure is based on (read: shamelessly stolen from) the generic kitchen
    # vagrant driver written by Fletcher Nichol and modified for our nefarious
    # purposes.

    class Metal < Kitchen::Driver::SSHBase

      def create(state)
        run_pre_create_command
        run_recipe
        set_ssh_state(state)
        info("Vagrant instance #{instance.to_str} created.")
      end

      def converge(state)
        run_recipe
        super
      end

      def setup(state)
        run_recipe
        super
      end

      def verify(state)
        run_recipe
        super
      end

      def destroy(state)
        run_destroy
        info("Vagrant instance #{instance.to_str} destroyed.")
      end

      protected

      def get_recipe
        "nope"
      end

      def run_recipe
        return if @environment_created
        recipe = get_recipe
        node = Chef::Node.new
        node.name 'test'
        node.automatic[:platform] = 'kitchen_metal'
        node.automatic[:platform_version] = 'kitchen_metal'
        Chef::Config.local_mode = true
        run_context = Chef::RunContext.new(node, {},
          Chef::EventDispatch::Dispatcher.new(Chef::Formatters::Doc.new(STDOUT,STDERR)))
        recipe_exec = Chef::Recipe.new('kitchen_vagrant_metal',
          'kitchen_vagrant_metal', run_context)

        recipe_exec.instance_eval do
          # STUFF HERE?
        end
        Chef::Runner.new(run_context).converge
        @environment_created = true
      end

      def run_destroy()
        @environment_created = false
      end

      def run(cmd, options = {})
        cmd = "echo #{cmd}" if config[:dry_run]
        run_command(cmd, { :cwd => config[:kitchen_root] }.merge(options))
      end

      def run_pre_create_command
        if config[:pre_create_command]
          run(config[:pre_create_command], :cwd => config[:kitchen_root])
        end
      end

      def set_ssh_state(state)
#        hash = vagrant_ssh_config

#        state[:hostname] = hash["HostName"]
#        state[:username] = hash["User"]
#        state[:ssh_key] = hash["IdentityFile"]
#        state[:port] = hash["Port"]
      end
    end
  end
end

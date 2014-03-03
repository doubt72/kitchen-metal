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

require 'chef/providers'
require 'chef/resources'
require 'chef_metal/vagrant'
require 'chef/formatters/doc'

module Kitchen
  module Driver

    # Vagrant Metal driver for Kitchen. It communicates to Vagrant using Chef Metal.
    #
    # @author Douglas Triggs <doug@getchef.com>
    #
    # This structure is based on (read: shamelessly stolen from) the generic kitchen
    # vagrant driver written by Fletcher Nichol and modified for our nefarious
    # purposes.

    class VagrantMetal < Kitchen::Driver::SSHBase

# Might want this?
#      default_config :customize, { :memory => '256' }

      default_config :provider,
        ENV.fetch('VAGRANT_DEFAULT_PROVIDER', "virtualbox")

      default_config :vm_hostname do |driver|
        "#{driver.instance.name}.vagrantup.com"
      end

      default_config :box do |driver|
        "opscode-#{driver.instance.platform.name}"
      end

      default_config :box_url do |driver|
        driver.default_box_url
      end

      required_config :box

#      no_parallel_for :create, :destroy

      def create(state)
        run_pre_create_command
        execute_recipe(:create)
        set_ssh_state(state)
        info("Vagrant instance #{instance.to_str} created.")
      end

      def converge(state)
        execute_recipe(:create, :converge => true)
        super
      end

      def setup(state)
        execute_recipe(:create, :converge => true)
        super
      end

      def verify(state)
        execute_recipe(:create, :converge => true)
        super
      end

      def destroy(state)
        execute_recipe(:delete)
        info("Vagrant instance #{instance.to_str} destroyed.")
      end

      def verify_dependencies
        check_vagrant_version
      end

      def default_box_url
        bucket = config[:provider]
        bucket = 'vmware' if config[:provider] =~ /^vmware_(.+)$/

        "https://opscode-vm-bento.s3.amazonaws.com/vagrant/#{bucket}/" +
          "opscode_#{instance.platform.name}_chef-provisionerless.box"
      end

      protected

      WEBSITE = "http://downloads.vagrantup.com/"
      MIN_VER = "1.1.0"

      def get_options
        options = Hash.new
        if (config[:guest])
          options['vm.guest'] = config[:guest]
        end
        if (config[:username])
          options['ssh.username'] = config[:username]
        end
        if (config[:ssh_key])
          options['ssh.private_key_path'] = config[:ssh_key]
        end
        return options
      end

      def get_text_options
        options = ""
        Array(config[:network]).each do |opts|
          options += "    config.vm.network(:#{opts[0]}, #{opts[1..-1].join(", ")})\n"
        end
        Array(config[:synced_folders]).each do |source, destination, opts|
          out_source = source.gsub("%{instance_name}", instance.name)
          out_destination = destination.gsub("%{instance_name}", instance.name)
          out_opts = (opts.nil? ? '' : ", #{opts}")
          options += "    config.vm.synced_folder \"#{out_source}\", " +
            "\"#{out_destination}\"#{out_opts}\n"
        end
        if (config[:customize])
          options += "    config.vm.provider :#{config[:provider]} do |p|\n"
          config[:customize].each do |key, value|
            if (config[:provider] == "virtualbox")
              options += "      p.customize [\"modifyvm\", :id, " +
                "\"--#{key}\", \"#{value}\"]\n"
            elsif (config[:provider] == "rackspace")
              options += "      p.#{key} = \"#{value}\"\n"
            elsif (config[:provider] =~ /^vmware_/)
              if (key == :memory)
                options += "      p.vmx[\"memsize\"] = \"#{value}\"\n"
              else
                options += "      p.vmx[\"#{key}\"] = \"#{value}\"\n"
              end
            end
          end
          options += "    end"
        end
        return options
      end

      def execute_recipe(run_action, options = {:converge => false})
        # WHY THIS NO WORK FOR MULTIPLE THINGS
        node = Chef::Node.new
        node.name 'test'
        node.automatic[:platform] = 'kitchen_vagrant_metal'
        node.automatic[:platform_version] = 'kitchen_vagrant_metal'
        Chef::Config.local_mode = true
        run_context = Chef::RunContext.new(node, {},
          Chef::EventDispatch::Dispatcher.new(Chef::Formatters::Doc.new(STDOUT,STDERR)))
        recipe = Chef::Recipe.new('kitchen_vagrant_metal', 'kitchen_vagrant_metal',
          run_context)
        box = config[:box]
        hostname = config[:vm_hostname]
        box_url = config[:box_url]
        root = vagrant_root

        vm_options = Hash.new
        part_options = get_options
        vm_options["vagrant_options"] = part_options if part_options.size > 0
        part_options = get_text_options
        vm_options["vagrant_config"] = part_options if part_options.length > 0
        recipe.instance_eval do
          directory root do
            recursive true
          end
          vagrant_cluster root

          directory "#{root}/repo"
          with_chef_local_server :chef_repo_path => "#{root}/repo"

          vagrant_box box do
            url box_url
            provisioner_options vm_options if vm_options.size > 0
          end

          machine hostname do
            action run_action
            converge options[:converge]
          end
        end
        Chef::Runner.new(run_context).converge
      end

      def run(cmd, options = {})
        cmd = "echo #{cmd}" if config[:dry_run]
        run_command(cmd, { :cwd => vagrant_root }.merge(options))
      end

      def silently_run(cmd)
        run_command(cmd,
          :live_stream => nil, :quiet => logger.debug? ? false : true)
      end

      def run_pre_create_command
        if config[:pre_create_command]
          run(config[:pre_create_command], :cwd => config[:kitchen_root])
        end
      end

      def vagrant_root
        @vagrant_root ||= File.join(
          config[:kitchen_root], %w{.kitchen kitchen-vagrant-metal}, instance.name
        )
      end

      def set_ssh_state(state)
        hash = vagrant_ssh_config

        state[:hostname] = hash["HostName"]
        state[:username] = hash["User"]
        state[:ssh_key] = hash["IdentityFile"]
        state[:port] = hash["Port"]
      end

      def vagrant_ssh_config
        output = run("vagrant ssh-config", :live_stream => nil)
        lines = output.split("\n").map do |line|
          tokens = line.strip.partition(" ")
          [tokens.first, tokens.last.gsub(/"/, '')]
        end
        Hash[lines]
      end

      def vagrant_version
        version_string = silently_run("vagrant --version")
        version_string = version_string.chomp.split(" ").last
      rescue Errno::ENOENT
        raise UserError, "Vagrant #{MIN_VER} or higher is not installed." +
          " Please download a package from #{WEBSITE}."
      end

      def check_vagrant_version
        version = vagrant_version
        if Gem::Version.new(version) < Gem::Version.new(MIN_VER)
          raise UserError, "Detected an old version of Vagrant (#{version})." +
            " Please upgrade to version #{MIN_VER} or higher from #{WEBSITE}."
        end
      end
    end
  end
end

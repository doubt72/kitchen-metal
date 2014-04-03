# -*- encoding: utf-8 -*-
#
# Author:: Douglas Triggs (<doug@getchef.com>)
#
# Copyright (C) 2014, Chef, Inc.
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

# This is used by the Test Kitchen metal driver for the parts of the provider interface
# that needs to be supported (though isn't necessarily for the things Kitchen needs the
# provisioner to do when called directly)

require 'chef_metal/action_handler'

module Kitchen
  class ActionHandler < ChefMetal::ActionHandler
    def initialize(name)
      @debug_name = name
    end

    def recipe_context
      # TODO: somehow remove this code; should context really always be needed?
      node = Chef::Node.new
      node.name 'nothing'
      node.automatic[:platform] = 'kitchen_metal'
      node.automatic[:platform_version] = 'kitchen_metal'
      Chef::RunContext.new(node, {},
        Chef::EventDispatch::Dispatcher.new(Chef::Formatters::Doc.new(STDOUT,STDERR)))
    end

    def debug_name
      @debug_name
    end
  end
end

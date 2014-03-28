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

module Kitchen
  class MetalHelper
    class Machine
      def initialize(node)
        @name = node["name"]
        @hostname = node["automatic"]["hostname"]
        @fqdn = node["automatic"]["fqdn"]
        @ipaddress = node["automatic"]["ipaddress"]
        @ipv6address = node["automatic"]["ipv6address"]
      end

      attr_accessor :name, :hostname, :fqdn, :ipaddress, :ipv6address
    end

    def self.add_machine(node)
      eigenclass = class <<self; self end
      eigenclass.class_eval do
        define_method(node["name"].to_sym) do
          Kitchen::MetalHelper::Machine.new(node)
        end
      end
    end
  end
end


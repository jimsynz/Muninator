# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
# The Original Code is Muninator Rails Plugin.
#
# The Initial Developer of the Original Code is James Harton.
#
# Portions created by the Initial Developer are Copyright (C) 2010
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****

module Muninator
  module Commands
    module Threads

      def self.config
        <<-EOS
graph_title Ruby Threads
graph_category threads
graph_info Threads started by this Ruby process
graph_vlabel threads
total.label Total threads
running.label Running threads
sleeping.label Sleeping threads
aborting.label Aborting threads
        EOS
      end

      def self.fetch
        <<-EOS
total.value #{Thread.list.size.to_s}
running.value #{Thread.list.collect { |t| t.status == "run" ? true : nil }.compact.size }
sleeping.value #{Thread.list.collect { |t| t.status == "sleep" ? true : nil }.compact.size }
aborting.value #{Thread.list.collect { |t| t.status == "abortin" ? true : nil }.compact.size }
        EOS
      end

    end
  end
end

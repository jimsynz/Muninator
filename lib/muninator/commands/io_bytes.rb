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
# Portions created by the Initial Developer are Copyright (C) 2010, 2011
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****


# Note: This module only works on Linux boxes.  If anyone
# can think of a way to make it work on OSX I would be
# v. happy.
if File.exist?('/' + File.join('proc', $$.to_s, 'io'))
  module Muninator
    module Commands
      class IoBytes
        def self.config
          <<-EOS
graph_title Process I/O
graph_category process
graph_info I/O usage of this Ruby process
graph_vlabel bytes
read.label Bytes read from storage
write.label Bytes written to storage
cancelled.label Cancelled write bytes
read.type COUNTER
write.type COUNTER
cancelled.type COUNTER
          EOS
        end

        def self.fetch
          data = { :read_bytes => 0, :write_bytes => 0, :cancelled_write_bytes => 0 }
          File.open('/' + File.join('proc', $$.to_s, 'io')).each do |line|
            k,v = line.chomp.split(': ')
            data[k.to_sym] = v.to_i
          end
          <<-EOS
read.value #{data[:read_bytes]}
write.value #{data[:write_bytes]}
cancelled.value #{data[:cancelled_write_bytes]}
          EOS
        end
      end
    end
  end
end

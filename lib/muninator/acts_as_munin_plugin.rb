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

module MashdCc
  module Acts
    module MuninPlugin

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_munin_plugin(opts={})
          model = self
          defaults = { :category => 'models', :label => "#{model.name} Usage" }
          opts = defaults.merge(opts)
          self.class_eval <<-RUBY
            module ::Muninator
              module Commands
                class #{model.name}Usage
                  def self.config
                    "graph_title Model #{opts[:label]}\n" +
                    "graph_category #{opts[:category]}\n" +
                    "graph_info Model count for model #{model.name}\n" +
                    "graph_vlabel models\n" +
                    "all.label All models\n" +
                    "updated.label Updated\n" +
                    "created.label Created\n"
                  end
                  def self.fetch
                    "all.value " + #{model.name}.count.to_s + "\n" +
                    "updated.value " + #{model.name}.count(:all, :conditions => [ "updated_at >= ?", 5.minutes.ago ]).to_s + "\n" +
                    "created.value " + #{model.name}.count(:all, :conditions => [ "created_at >= ?", 5.minutes.ago ]).to_s + "\n"
                  end
                end
              end
            end
          RUBY
        end
      end

    end
  end
end

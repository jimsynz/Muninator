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
  module Controller
    module Munin

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods

        def monitor_with_munin(opts = {})
          defaults = { :actions => [ :all ], :controller => self.controller_name, :category => 'controllers' }
          opts = defaults.merge(opts)
          if opts[:actions].member? :all
            # For now ActionController::Base#action_methods is wrong, so just
            # pretend everyone just uses RESTful controllers.
            opts[:actions] = [ :index, :new, :create, :show, :edit, :update, :destroy ]
          else
            opts[:actions] = opts[:actions].collect { |action| action.to_sym }
          end
          class_eval <<-RUBY
            # Create the Muninator command for controller_hits
            module ::Muninator
              module Commands
                class #{"#{opts[:controller]}_hits".camelize} < ::MashdCc::Controller::Munin::Hits
                end
              end
            end
            ::Muninator::Commands::#{"#{opts[:controller]}_hits".camelize}.setup(opts)
            after_filter ::Muninator::Commands::#{"#{opts[:controller]}_hits".camelize}

            # Create the Muninator command for controller_latency
            module ::Muninator
              module Commands
                class #{"#{opts[:controller]}_latency".camelize} < ::MashdCc::Controller::Munin::Latency
                end
              end
            end
            ::Muninator::Commands::#{"#{opts[:controller]}_latency".camelize}.setup(opts)
            around_filter ::Muninator::Commands::#{"#{opts[:controller]}_latency".camelize}

            # Create the Muninator command for controller_response
            module ::Muninator
              module Commands
                class #{"#{opts[:controller]}_response".camelize} < ::MashdCc::Controller::Munin::Response
                end
              end
            end
            ::Muninator::Commands::#{"#{opts[:controller]}_response".camelize}.setup(opts)
            after_filter ::Muninator::Commands::#{"#{opts[:controller]}_response".camelize}
          RUBY
        end

      end
      
      class Hits
        def self.setup(opts)
          @actions = opts[:actions]
          @controller = opts[:controller]
          @category = opts[:category]
          clean
        end

        def self.filter(controller)
          if @actions.member? controller.params[:action].to_sym
            @hits[controller.params[:action].to_sym] = @hits[controller.params[:action].to_sym] + 1
          end
          1
        end

        def self.config
          r = <<-EOS
graph_title Controller #{@controller} Hits
graph_category #{@category}
graph_info Action hits on controller #{@controller}
graph_vlabel hits
          EOS
          @actions.each do |action|
            r += "#{action.to_s}.label Hits to #{action.to_s.camelize}\n"
          end
          r
        end
        
        def self.fetch
          r = @actions.collect do |action|
            "#{action.to_s}.value #{@hits[action]}"
          end
          clean
          r * "\n"
        end

        private

        def self.clean
          @hits = {}
          @actions.each do |action|
            @hits[action] = 0
          end
        end
      end

      class Latency
        def self.setup(opts)
          @actions = opts[:actions]
          @controller = opts[:controller]
          @category = opts[:category]
          clean
        end

        def self.filter(controller)
          if @actions.member? controller.params[:action].to_sym
            start = Time.now
            yield
            took = Time.now - start
            @latency[controller.params[:action].to_sym] << took
          else 
            yield
          end
          1
        end

        def self.config
          r = <<-EOS
graph_title Controller #{@controller} Response Time
graph_category #{@category}
graph_info Response time of hits on controller #{@controller}
graph_vlabel seconds
          EOS
          @actions.each do |action|
            r += "#{action.to_s}_avg.label average response time of #{action.to_s.camelize}\n"
            r += "#{action.to_s}_min.label minimum response time of #{action.to_s.camelize}\n"
            r += "#{action.to_s}_max.label maximum response time of #{action.to_s.camelize}\n"
          end
          r
        end
        
        def self.fetch
          r = @actions.collect do |action|
            [ "#{action.to_s}_avg.value #{@latency[action].empty? ? 0 : @latency[action].sum.to_f / @latency[action].size}",
              "#{action.to_s}_min.value #{(@latency[action].min) || 0}",
              "#{action.to_s}_max.value #{(@latency[action].max) || 0}" ]
          end
          clean
          r.flatten * "\n"
        end

        private

        def self.clean
          @latency = {}
          @actions.each do |action|
            @latency[action] = []
          end
        end
      end

      class Response
        def self.setup(opts)
          @actions = opts[:actions]
          @controller = opts[:controller]
          @category = opts[:category]
          clean
        end

        def self.filter(controller)
          if @actions.member? controller.params[:action].to_sym
            @size[controller.params[:action].to_sym] << (controller.response.body.nil? ? 0 : controller.response.body.size)
          end
          1
        end

        def self.config
          r = <<-EOS
graph_title Controller #{@controller} Response Size
graph_category #{@category}
graph_info Response size of hits on controller #{@controller}
graph_vlabel bytes
          EOS
          @actions.each do |action|
            r += "#{action.to_s}_avg.label average response size of #{action.to_s.camelize}\n"
            r += "#{action.to_s}_min.label minimum response size of #{action.to_s.camelize}\n"
            r += "#{action.to_s}_max.label maximum response size of #{action.to_s.camelize}\n"
          end
          r
        end
        
        def self.fetch
          r = @actions.collect do |action|
            [ "#{action.to_s}_avg.value #{@size[action].empty? ? 0 : @size[action].sum.to_f / @size[action].size}",
              "#{action.to_s}_min.value #{(@size[action].min) || 0}",
              "#{action.to_s}_max.value #{(@size[action].max) || 0}" ]
          end
          clean
          r.flatten * "\n"
        end

        private

        def self.clean
          @size = {}
          @actions.each do |action|
            @size[action] = []
          end
        end
      end

    end
  end
end

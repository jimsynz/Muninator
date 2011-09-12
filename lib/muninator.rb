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

module Muninator

  require 'socket'
  require 'timeout'

  class InvalidConfig < Exception; end

  class << self

    attr_accessor :config
    @running = false

    def version
      "2010.5.5"
    end

    def setup
      Commands.search_paths << Rails.root.join('app/munin').to_s
      Template.paths << Rails.root.join('app/munin').to_s
      load_config
    end


    # sets up paths and starts the server +from_config+
    def boot
      setup
      if standalone?
        raise InvalidConfig, "please set standalone: false to run inside your rails application"
      end
      # Add callback for Passenger to restart Muninator if needed.
      if defined?(PhusionPassenger)
        PhusionPassenger.on_event(:starting_worker_process) do |forked|
          if forked
            if @running == true
              restart
            else
              start
            end
          else
            start
          end
        end
      else
        start
      end
    end

    # boots up in standalone mode
    def boot_standalone
      setup
      unless standalone?
        raise InvalidConfig, "please set standalone: true to run outside of rails process"
      end
      log "Muninator starting up in standalone mode"
      start
    end

    def standalone?
      load_config
      config['standalone'] == true
    end

    def clear_config
      @config = nil
    end

    def port
      config['port']
    end

    def server_name
      config['server_name']
    end

    protected

    def load_config( file = config_path, reload = false )
      return @config if @config && !reload
      loaded = YAML.load_file(file)
      @config = loaded[Rails.env] || {}
      if config['restrict']
        if config['restrict'] == 'localhost'
          restrict_to :localhost
        else
          restrict_to config['restrict'].split(',').collect { |r| r = r.strip ; r == "" ? nil : r }.compact
        end
      end
      @config
    end

    def config_path
      Rails.root.join("config", "muninator.yml")
    end

    def lockfile
      @lockfile ||= Rails.root.join('tmp', "muninator_port_#{port.to_s}.lock")
    end

    # checks if lockfile exists and if it's stale.
    def cleanup
      if File.exist? lockfile
        # The PIDfile exists, but let's check that it's not stale.
        f = File.open(lockfile, "r") # FIXME why not File.read?
        pid = f.gets.chomp.to_i
        f.close
        if pid > 0
          begin
            Process.kill(0,pid)
          rescue Errno::ESRCH => e
            # Lockfile is stale, nuke it.
            log("Overriding stale lockfile #{lockfile}")
            File.delete(lockfile)
          end
        end
      end
    end

    def start
      raise RuntimeError, "no port set" if port.blank?

      cleanup

      if File.exist?(lockfile)
        # If the lockfile exists, then let's just wait 2 minutes
        # and check it again - I think this is the best way to
        # make sure that there is the greatest chance that muninator
        # is still listenening when munin comes around to check.
        Thread.new do
          # well, two and a bit, actually.
          sleep(120 + rand(120))
          start
        end
      else
        if standalone?
          Signal.trap "INT", proc { stop }
          run.join
        else
          Thread.new do 
            run
          end
        end
      end
    end

    # actually starts the server, will be called from +start+ in a Thread (or not), depending on standalone?
    def run
      Commands.load_all
      Template.load_all
      @server = TCPServer.open(port)
      log("Opening port #{port} as Munin Node.")
      File.open(lockfile, "w+") do |io|
        io.puts $$
      end
      @running = true
      at_exit do
        @server.close rescue IOError
        if File.exist? lockfile 
          File.delete(lockfile)
        end
        log("Closing Munin Node on port #{port}.")
      end
      @proc = Thread.new do
        loop do
          begin 
            client = @server.accept_nonblock
            log("Accepting connection from #{client.peeraddr.last}")
            if ((@restrict ||= []).size > 0) && (! @restrict.member? client.peeraddr.last)
              client.close
            else
              Thread.new do 
                Client.new(client)
              end
            end
          rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
            IO.select([@server])
            retry
          end
        end
      end
    end

    def stop
      begin
        @server.close
      rescue
      end
      begin
        @proc.kill
      rescue
      end
    end

    def restart
      if @running == true
        stop
        start
      end
    end

    def restrict_to(what)
      @restrict ||= []
      if what == :localhost
        @restrict += [ '::1', 'fe80::1', '127.0.0.1' ]
      elsif what.is_a? Array
        @restrict += what
      elsif what.is_a? String
        @restrict += what
      end
    end

    def log(message='')
      if standalone?
        STDERR.puts message
      else
        Rails.logger.info message
      end
    end

  end

end

require 'muninator/client'
require 'muninator/commands'
require 'muninator/template'

require 'muninator/acts_as_munin_plugin.rb'
require 'muninator/monitor_controller.rb'

require 'muninator/rail_tie.rb' if defined?(Rails) && defined?(Rails::Railtie)

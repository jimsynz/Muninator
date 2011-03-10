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

  require 'socket'
  require 'timeout'

  class << self

    attr_accessor :port, :server_name
    @running = false

    def from_config
      config = YAML.load_file(Rails.root.join("config", "muninator.yml"))
      conf = config[Rails.env] || {}
      if conf['restrict']
        if conf['restrict'] == 'localhost'
          restrict_to :localhost
        else
          restrict_to conf['restrict'].split(',').collect { |r| r = r.strip ; r == "" ? nil : r }.compact
        end
      end
      if defined?(PhusionPassenger)
        PhusionPassenger.on_event(:starting_worker_process) do |forked|
          if forked
            if @running == true
              Muninator.restart
            else
              Muninator.start(conf['port'], conf['server_name'])
            end
          else
            Muninator.start(conf['port'], conf['server_name'])
          end
        end
      else
        start(conf['port'], conf['server_name'])
      end
    end

    def start(port, server_name)
      @port = port
      @server_name = server_name
      @lockfile = Rails.root.join('tmp', "muninator_port_#{port.to_s}.lock")
      # Add callback for Passenger to restart Muninator if needed.
      if File.exist? @lockfile
        # The PIDfile exists, but let's check that it's not stale.
        f = File.open(@lockfile, "r")
        pid = f.gets.chomp.to_i
        f.close
        if pid > 0
          begin
            Process.kill(0,pid)
          rescue Errno::ESRCH => e
            # Lockfile is stale, nuke it.
            Rails.logger.warn("Overriding stale lockfile #{@lockfile}")
            File.delete(@lockfile)
          end
        end
      end
      if File.exist?(@lockfile)
        # If the lockfile exists, then let's just wait 2 minutes
        # and check it again - I think this is the best way to
        # make sure that there is the greatest chance that muninator
        # is still listenening when munin comes around to check.
        Thread.new do
          # well, two and a bit, actually.
          sleep(120 + rand(120))
          start(port, server_name)
        end
      else
        # Attempt to start the server only if the pid file isn't
        # there.
        Thread.new do 
          Muninator::Commands.load_all
          @server = TCPServer.open(port)
          Rails.logger.info("Opening port #{port} as Munin Node.")
          File.open(@lockfile, "w+") do |io|
            io.puts $$
          end
          @running = true
          at_exit do
            @server.close
            if File.exist? @lockfile 
              File.delete(@lockfile)
            end
            Rails.logger.info("Closing Munin Node on port #{port}.")
          end
          @port = port
          @server_name = server_name
          @proc = Thread.new do
            loop do
              begin 
                client = @server.accept_nonblock
                Rails.logger.info("Accepting connection from #{client.peeraddr.last}")
                if ((@restrict ||= []).size > 0) && (! @restrict.member? client.peeraddr.last)
                  client.close
                else
                  Thread.new do 
                    Muninator::Client.new(client)
                  end
                end
              rescue Errno::EAGAIN, Errno::ECONNABORTED, Errno::EPROTO, Errno::EINTR
                IO.select([@server])
                retry
              end
            end
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
        start(@port, @server_name)
      end
    end

    def version
      "2010.5.5"
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

  end

  class Client

    class Quit < Exception; end

    def initialize(socket)
      @socket = socket
      start_session
    end

    def start_session(timeout=60)
      Timeout.timeout(60) do
        begin
          out "# munin node at #{Muninator.server_name}"
          while line = @socket.gets do
            line.chomp!
            debug { "Received #{line.inspect} from client." }
            dispatch *line.split(' ')
          end
        rescue Quit => e
          debug { "quitting" }
          @socket.close
        rescue Exception => e
          out "# Error: #{e.message}"
          debug { ([e.message] + e.backtrace).join("\n") }
        ensure
          @socket.close
        end
      end
    end

    def dispatch(cmd=nil, *args)
      case cmd 
      when "list"
        out Muninator::Commands.list * " "
      when "nodes"
        out Muninator.server_name
        out "."
      when "config"
        if command = Muninator::Commands.find(args.first)
          out command.config
        else
          out "# Unknown service"
        end
        out "."
      when "fetch"
        if command = Muninator::Commands.find(args.first)
          out command.fetch
        else
          out "# Unknown service"
        end
        out "."
      when "version"
        out "Muninator on #{Muninator.server_name} version: #{Muninator.version}"
      when "quit"
        raise Quit
      when nil
        out "# no comment about an empty line"
      else
        out "# Unknown command. Try list, nodes, config, fetch, version or quit"
      end
    end

    def out(message)
      @socket.puts message
    end

    def debug
      Rails.logger.debug do
        "Muninator #{yield}"
      end
    end

  end

  module Commands


    class << self

      attr_writer :search_paths

      def search_paths
        @search_paths ||=  [ File.join(File.dirname(__FILE__), 'commands') ]
      end

      def load_all
        files.each do |path|
           basename = File.basename(path)
           class_name = basename.split('.').first.classify
           unless constants.grep(/^#{class_name}$/).empty?
             # TODO already loaded. unload?
           else
             require_dependency path
          end
        end
      end
      def list
        self.constants.collect { |name| name.to_s.underscore }.sort
      end

      # finds class by command, returns nil if not found
      def find(command)
        if list.member? command
          constant_name(command).constantize
        else
          nil
        end
      end

      private
      def files
        search_paths.map do |path|
          Dir.glob path.ends_with?('/') ? "#{path}*.rb" : "#{path}/*.rb"
        end.flatten.uniq
      end

      def constant_name(command)
        "::Muninator::Commands::#{command.to_s.camelize}"
      end
    end

  end

end


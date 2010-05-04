module Muninator

  require 'socket'
  require 'timeout'

  class << self

    attr_accessor :port, :server_name
    @running = false

    def from_config
      config = YAML.load_file(File.join(RAILS_ROOT, "config", "muninator.yml"))
      conf = config[RAILS_ENV] || {}
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
      @lockfile = File.join(RAILS_ROOT, 'tmp', "muninator_port_#{port.to_s}.lock")
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
            RAILS_DEFAULT_LOGGER.warn("Overriding stale lockfile #{@lockfile}")
            File.delete(@lockfile)
          end
        end
      end
      # Attempt to start the server only if the pid file isn't
      # there.
      if File.exist?(@lockfile) == false
        Thread.new do 
          Muninator::Commands.reload
          @server = TCPServer.open(port)
          RAILS_DEFAULT_LOGGER.info("Opening port #{port} as Munin Node.")
          File.open(@lockfile, "w+") do |io|
            io.puts $$
          end
          @running = true
          at_exit do
            @server.close
            if File.exist? @lockfile 
              File.delete(@lockfile)
            end
            RAILS_DEFAULT_LOGGER.info("Closing Munin Node on port #{port}.")
          end
          @port = port
          @server_name = server_name
          @proc = Thread.new do
            loop do
              begin 
                client = @server.accept_nonblock
                RAILS_DEFAULT_LOGGER.info("Accepting connection from #{client.peeraddr.last}")
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
      "2010.5.3"
    end

    def restrict_to(what)
      if what == :localhost
        @restrict = [ '::1', 'fe80::1', '127.0.0.1' ]
      elsif what.is_a? Array
        @restrict += what
      elsif what.is_a? String
        @restruct += what
      end
    end

  end

  class Client

    def initialize(socket)
      @socket = socket
      Timeout.timeout(60) do
        begin
          @socket.puts "# munin node at #{Muninator.server_name}"
          while line = @socket.gets do
            line.chomp!
            RAILS_DEFAULT_LOGGER.debug("Received #{line.inspect} from client.")
            cmd = line.split(' ').first
            args = line.split(' ')[1..-1]
            case cmd 
            when "list"
              @socket.puts Muninator::Commands.list * " "
            when "nodes"
              @socket.puts Muninator.server_name
              @socket.puts "."
            when "config"
              if Muninator::Commands.list.member? args.first
                begin
                  instance_eval <<-RUBY
                  @socket.puts Muninator::Commands::#{args.first.camelize}.config
                  RUBY
                rescue Exception => e
                  @socket.puts "# Error: #{e.message}"
                end
              else
                @socket.puts "# Unknown service"
              end
              @socket.puts "."
            when "fetch"
              if Muninator::Commands.list.member? args.first
                begin
                  instance_eval <<-RUBY
                  @socket.puts Muninator::Commands::#{args.first.camelize}.fetch
                  RUBY
                rescue Exception => e
                  @socket.puts "# Error: #{e.message}"
                  RAILS_DEFAULT_LOGGER.debug(e.inspect)
                end
              else
                @socket.puts "# Unknown service"
              end
              @socket.puts "."
            when "version"
              @socket.puts "Muninator on #{Muninator.server_name} version: #{Muninator.version}"
            when "quit"
              break
            else
              @socket.puts "# Unknown command. Try list, nodes, config, fetch, version or quit"
            end
          end
        ensure
          @socket.close
        end
      end
    end

  end

  module Commands


    class << self

      attr_accessor :search_paths

      def reload
        @search_paths ||=  [ File.join(File.dirname(__FILE__), 'commands') ]
        @search_paths.each do |dir|
          Dir.entries(dir).each do |file|
            if file =~ /\.rb$/
              if self.constants.collect { |name| name.downcase }.member? file.split('.').first
                # remove constant, blah.
              else
                require File.join(dir, file)
              end
            end
          end
        end
        # Add class reloading, but for now...
        require File.dirname(__FILE__) + '/commands/memory.rb'
      end
      def list
        self.constants.collect { |name| name.underscore }.sort
      end
    end

  end

end


module Muninator

  require 'socket'
  require 'timeout'

  class << self

    attr_accessor :port, :server_name

    def from_config
      conf = YAML.load_file(File.join(RAILS_ROOT, "config", "muninator.yaml"))[RAILS_ENV]
      if conf['restrict']
        if conf['restrict'] == 'localhost'
          restrict_to :localhost
        else
          restrict_to conf['restrict'].split(',').collect { |r| r = r.strip ; r == "" ? nil : r }.compact
        end
      end
      start(conf['port'], conf['server_name'])
    end

    def start(port, server_name)
      @lockfile = File.join(RAILS_ROOT, 'tmp', "muninator_port_#{port.to_s}.lock")
      unless File.exists? @lockfile
        File.open(@lockfile, "w+") do |io|
          io.puts $$
        end
        Muninator::Commands.reload
        @server = TCPServer.open(port)
        at_exit do
          @server.close
          File.delete(@lockfile)
        end
        @port = port
        @server_name = server_name
        @proc = Thread.new do
          loop do
            client = @server.accept
            if ((@restrict ||= []).size > 0) && (! @restrict.member? client.peeraddr.last)
              client.close
              next
            end
            Thread.new do
              Muninator::Client.new(client)
            end
          end
        end
      end
    end

    def stop
      @proc.kill
    end

    def version
      "2010.4.30"
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
      Timeout.timeout(30) do
        begin
          @socket.puts "# munin node at #{Muninator.server_name}"
          while line = @socket.gets do
            line.chomp!
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
                  @socket.puts Muninator::Commands::#{args.first[0..0].upcase + args.first[1..-1]}.config
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
                  @socket.puts Muninator::Commands::#{args.first[0..0].upcase + args.first[1..-1]}.fetch
                  RUBY
                rescue Exception => e
                  @socket.puts "# Error: #{e.message}"
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
        self.constants.collect { |name| name.downcase }.sort
      end
    end

  end

end


module Muninator
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
end

require 'erb'
module Muninator
  class Template < Struct.new(:command, :base_path)
    ConfigExt = /\.config$/
    class << self
      attr_writer :paths

      def paths
        @paths ||= []
      end
      def list
        @list ||= []
      end
      def find(command)
        list.find {|t| t.command == command }
      end
      def commands
        list.map(&:command)
      end
      def load_all
        list.clear
        config_files.map do |config_path|
          fetch_path = config_path.sub(ConfigExt, '.fetch')
          if File.exists?(fetch_path)
            c = File.basename(config_path).sub(ConfigExt,'')
            list << new(c, config_path.sub(ConfigExt, ''))
          end
        end
      end

      def config_files
        paths.map do |path|
          Dir.glob path =~ %r~/$~ ? 
             "#{path}*.config" : 
             "#{path}/*.config"
        end.flatten.uniq
      end
    end

    def config
      config_erb.result(binding)
    end

    def fetch
      fetch_erb.result(binding)
    end

    def config_path
      base_path + '.config'
    end

    def fetch_path
      base_path + '.fetch'
    end

    private

    def config_erb
      @config_erb ||= ERB.new File.read(config_path)
    end

    def fetch_erb
      @fetch_erb ||= ERB.new File.read(fetch_path)
    end
  end
end

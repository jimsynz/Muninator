module Muninator
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
            Rails.logger.debug { "#{self} require #{path}" }
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
          Rails.logger.debug { "#{self} files #{path}" }
          Dir.glob path.ends_with?('/') ? "#{path}*.rb" : "#{path}/*.rb"
        end.flatten.uniq
      end

      def constant_name(command)
        "::Muninator::Commands::#{command.to_s.camelize}"
      end
    end

  end

end

module Muninator
  module Commands
    class Cpu
      def self.config
        <<-EOS
graph_title CPU Usage
graph_category process
graph_info CPU usage by this Ruby process
graph_vlabel %
cpu.label Resident Memory Usage
        EOS
      end
      def self.fetch
        <<-EOS
cpu.value #{`ps -o %cpu= -p #{$$}`.to_i}
        EOS
      end
    end
  end
end

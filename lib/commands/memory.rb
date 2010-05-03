module Muninator
  module Commands
    class Memory
      def self.config
        <<-EOS
graph_title Memory Usage
graph_category memory
graph_info Memory usage by this Ruby process
graph_vlabel kbytes
mem.label RSS Memory Usage
        EOS
      end
      def self.fetch
        <<-EOS
mem.value #{`ps -o rss= -p #{$$}`.to_i}
        EOS
      end
    end
  end
end

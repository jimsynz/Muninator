module Muninator
  module Commands
    class Memory
      def self.config
        <<-EOS
graph_title Memory Usage
graph_category process
graph_info Memory usage by this Ruby process
graph_vlabel kbytes
rss.label Resident Memory Usage
vsz.label Virtual Memory Usage
        EOS
      end
      def self.fetch
        rss,vsz = `ps -o rss=,vsz= -p #{$$}`.strip.squeeze(' ').split(' ')
        <<-EOS
rss.value #{rss}
vzs.value #{vsz}
        EOS
      end
    end
  end
end

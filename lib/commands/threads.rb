module Muninator
  module Commands
    module Threads

      def self.config
        <<-EOS
graph_title Ruby Threads
graph_category threads
graph_info Threads started by this Ruby process
graph_vlabel number
total.label "Total threads"
running.label "Running threads"
sleeping.label "Sleeping threads"
abording.label "Aborting threads"
        EOS
      end

      def self.fetch
        <<-EOS
total.value #{Thread.list.size.to_s}
running.value #{Thread.list.collect { |t| t.status == "run" ? true : nil }.compact.size }
sleeping.value #{Thread.list.collect { |t| t.status == "sleep" ? true : nil }.compact.size }
aborting.value #{Thread.list.collect { |t| t.status == "abortin" ? true : nil }.compact.size }
        EOS
      end

    end
  end
end

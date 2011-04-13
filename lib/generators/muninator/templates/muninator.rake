namespace :muninator do
  # TODO do not check against running server
  desc "validates your munin plugins and templates"
  task :lint  do
    munin = TCPSocket.new('localhost', 4950)
      munin.gets =~ %r~^# munin node at~ || fail("no greeting by node")

      munin << "list\n"
      list = munin.gets
      list.blank? && fail("list is blank")

      list.split.each do |s|
        graph_title = false
        graph_info = false
        graph_vlabel = false
        labels = []
        fields_with_values = []

        munin << "config #{s}\n"
        while (line = munin.gets) && (!line.starts_with?('.'))
          line.chomp!
          case line
          when /^(\w+)\.label\s+(.*)$/
            labels << $1
          when /^(\w+)\.type\s+(.*)$/
            f,t = $1, $2
            unless labels.include?(f)
              fail("#{s} specified type for #{f} but has no label")
            end
            unless %w(GAUGE COUNTER).include?(t)
              fail("#{s} illegal type for #{f}: #{t}")
            end
          when /^(\w+)\.draw\s+(.*)$/
            f,t = $1, $2
            unless labels.include?(f)
              fail("#{s} specified draw for #{f} but has no label")
            end
            unless t =~ /^LINE[123]|AREA|STACK|LINESTACK[123]|AREASTACK$/
              fail("#{s} illegal type for #{f}: #{t}")
            end
          when /^(\w+)\.min\s+(.*)$/
            f,t = $1, $2
            unless labels.include?(f)
              fail("#{s} specified minimum for #{f} but has no label")
            end
          when /^graph_title\s+(.*)$/
            graph_title = $1
          when /^graph_info\s+(.*)$/
            graph_info = $1
          when /^graph_vlabel\s+(.*)$/
            graph_vlabel = $1
          when /^graph_(?:category|args|scale)/
            # ignore good things, won't check syntax
          when /^\s*$/m
            # ignore empty lines
          when /^#/
            # ignore comments
          else
            puts "ignoring: '#{line}'"
          end
        end

        unless graph_title
          fail("#{s} has no graph_title")
        end
        unless graph_info
          fail("#{s} has no graph_info")
        end
        unless graph_vlabel
          fail("#{s} has no graph_vlabel")
        end

        munin << "fetch #{s}\n"
        while (line = munin.gets) && (!line.starts_with?('.'))
          line.chomp!
          case line
          when /^(\w+)\.value\s+(.*)$/
            fields_with_values << $1
          when /^\s*$/m
            # ignore empty lines
          when /^#/
            # ignore comments
          else
            puts "ignoring: '#{line}'"
          end
        end

        if labels.empty?
          fail("#{s} has no labels defined")
        end

        if fields_with_values.empty?
          fail("#{s} has no values defined")
        end

        if labels != fields_with_values
          puts "labels: #{labels.inspect}"
          puts "fields_with_values: #{fields_with_values.inspect}"
          fail("non-matching labels or values")
        end

        puts " #{s} => #{labels.join(' ')}"
      end
      munin << "quit\n"
    munin.close

    puts "SUCCESS!"
  end
end

module MashdCc
  module Acts
    module MuninPlugin

      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def acts_as_munin_plugin(opts={})
          model = self
          defaults = { :category => 'models', :label => "#{model.name} Usage" }
          opts = defaults.merge(opts)
          self.class_eval <<-RUBY
            module ::Muninator
              module Commands
                class #{model.name}Usage
                  def self.config
                    "graph_title Model #{opts[:label]}\n" +
                    "graph_category #{opts[:category]}\n" +
                    "graph_info Model count for model #{model.name}\n" +
                    "graph_vlabel models\n" +
                    "all.label All models\n" +
                    "updated.label Updated\n" +
                    "created.label Created\n"
                  end
                  def self.fetch
                    "all.value " + #{model.name}.count.to_s + "\n" +
                    "updated.value " + #{model.name}.count(:all, :conditions => [ "updated_at >= ?", 5.minutes.ago ]).to_s + "\n" +
                    "created.value " + #{model.name}.count(:all, :conditions => [ "created_at >= ?", 5.minutes.ago ]).to_s + "\n"
                  end
                end
              end
            end
          RUBY
        end
      end

    end
  end
end

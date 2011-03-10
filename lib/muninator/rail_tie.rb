module Muninator
  class RailTie < ::Rails::Railtie
    initializer "muninator" do
      ActiveRecord::Base.send(:include, MashdCc::Acts::MuninPlugin)
      ActionController::Base.send(:include, MashdCc::Controller::Munin)
      if Rails.env.production? || Rails.env.development?
        Muninator::Commands.search_paths << Rails.root.join('app/munin').to_s
        Muninator::Template.paths << Rails.root.join('app/munin').to_s
        Muninator.from_config
      end
    end
  end
end

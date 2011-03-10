module Muninator
  class RailTie < ::Rails::Railtie
    initializer "muninator" do
      if Rails.env.production? || Rails.env.development?
        Muninator::Commands.search_paths << Rails.root.join('app/munin').to_s
        Muninator.from_config
      end
    end

  end
end

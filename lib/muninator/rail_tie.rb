module Muninator
  class RailTie < ::Rails::Railtie
    initializer "muninator" do
      ActiveRecord::Base.send(:include, MashdCc::Acts::MuninPlugin)
      ActionController::Base.send(:include, MashdCc::Controller::Munin)
      if Rails.env.production? || Rails.env.development?
        Muninator.boot unless Muninator.standalone?
      end
    end
  end
end

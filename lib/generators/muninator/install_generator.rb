require 'rails/generators/base'
module Muninator
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path("../templates", __FILE__)

    def copy_script
      copy_file 'script', 'script/muninator'
      chmod 'script/muninator', 0755
    end

    def copy_rake_file
      copy_file 'muninator.rake', 'lib/tasks/muninator.rake'

    end

    def generate_config
      template 'muninator.yml.erb', 'config/muninator.yml'
    end

    private

    def app_name
      Rails.root.basename
    end
  end
end

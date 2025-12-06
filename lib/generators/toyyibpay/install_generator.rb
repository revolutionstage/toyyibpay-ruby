# frozen_string_literal: true

require "rails/generators/base"

module Toyyibpay
  module Generators
    # Rails generator for installing ToyyibPay
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Creates a ToyyibPay initializer file"

      def copy_initializer
        template "toyyibpay.rb", "config/initializers/toyyibpay.rb"
      end

      def show_readme
        readme "README" if behavior == :invoke
      end
    end
  end
end

# frozen_string_literal: true

require_relative "lib/toyyibpay/version"

Gem::Specification.new do |spec|
  spec.name = "toyyibpay-ruby"
  spec.version = ToyyibPay::VERSION
  spec.authors = ["KintsugiDesign"]
  spec.email = ["developers@kintsugidesign.com"]

  spec.summary = "Ruby bindings for the toyyibPay API"
  spec.description = "toyyibPay is a Malaysian payment gateway. This gem provides Ruby bindings for the toyyibPay API, with support for both plain Ruby and Ruby on Rails applications."
  spec.homepage = "https://github.com/revolutionstage/toyyibpay-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/revolutionstage/toyyibpay-ruby"
  spec.metadata["changelog_uri"] = "https://github.com/revolutionstage/toyyibpay-ruby/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/revolutionstage/toyyibpay-ruby/issues"
  spec.metadata["documentation_uri"] = "https://github.com/revolutionstage/toyyibpay-ruby"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("lib/**/*.rb") + %w[
    README.md
    CHANGELOG.md
    LICENSE.txt
  ]
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "faraday-multipart", "~> 1.0"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.0"
  spec.add_development_dependency "rubocop-rspec", "~> 2.0"
  spec.add_development_dependency "yard", "~> 0.9"
end

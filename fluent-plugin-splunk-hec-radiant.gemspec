# frozen_string_literal: true

require_relative "lib/fluent/plugin/splunk_hec_radiant/version"

Gem::Specification.new do |spec|
  spec.name = "fluent-plugin-splunk-hec-radiant"
  spec.version = Fluent::Plugin::SplunkHecRadiant::VERSION
  spec.authors = ["G. Rahul Nutakki"]
  spec.email = ["gnanirn@gmail.com"]

  spec.summary = "Modernized Fluentd output plugin for Splunk HEC"
  spec.description = "A modernized and actively maintained Fluentd output plugin for " \
                     "Splunk HTTP Event Collector (HEC) with updated dependencies, " \
                     "improved performance, and Ruby 3.x support. Forked from the " \
                     "original Splunk plugin with enhancements and bug fixes."
  spec.homepage = "https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant"
  spec.license = "Apache-2.0"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant"
  spec.metadata["changelog_uri"] = "https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant/issues"
  spec.metadata["documentation_uri"] = "https://github.com/gnanirahulnutakki/fluent-plugin-splunk-hec-radiant/blob/main/README.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob("lib/**/*") + %w[
    README.md
    LICENSE
    NOTICE
    fluent-plugin-splunk-hec-radiant.gemspec
    Gemfile
    Rakefile
  ]
  spec.require_paths = ["lib"]

  # Runtime dependencies - modernized versions
  spec.add_dependency "fluentd", ">= 1.16", "< 2.0"
  spec.add_dependency "net-http-persistent", ">= 4.0", "< 6.0"
  spec.add_dependency "oj", "~> 3.16"
  spec.add_dependency "prometheus-client", ">= 2.1.0", "< 4.0"

  # Development dependencies
  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "test-unit", "~> 3.6"
  spec.add_development_dependency "webmock", "~> 3.23"
end

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"
require "coverage_helper"
require File.expand_path("../spec/dummy/config/environment.rb", __dir__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "spec_helper"
require "rspec/rails"
require "sidekiq/testing"

RSpec.configure do |config|
  config.include ActiveJob::TestHelper
  config.include ActiveSupport::Testing::Assertions
  config.include ActiveSupport::Testing::TimeHelpers
  config.filter_rails_from_backtrace!
end

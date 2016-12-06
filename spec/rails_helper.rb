# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"
require "coverage_helper"
require File.expand_path("../../spec/dummy/config/environment.rb", __FILE__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "spec_helper"
require "rspec/rails"
require "timecop"

RSpec.configure do |config|
  config.include ActiveJob::TestHelper
  config.filter_rails_from_backtrace!
end

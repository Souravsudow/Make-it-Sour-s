# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

# SimpleCov must be loaded BEFORE the application
require 'simplecov'
SimpleCov.start do
  skip '/spec/'
  skip '/config/'
  skip '/bin/'
  group 'Services', 'app/services'
  group 'Controllers', 'app/controllers'
end

require_relative '../config/environment'
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require 'rspec/rails'
require 'webmock/rspec'

# Add additional requires below this line.

RSpec.configure do |config|
  # Remove this line to enable support for ActiveRecord
  config.use_active_record = false

  # provide have_enqueued_job / perform_enqueued_jobs matchers
  config.include ActiveJob::TestHelper

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  # Allow WebMock to connect to Redis in test
  WebMock.allow_net_connect!(net_http_connect_on_start: true)

  # Stub Redis globally to prevent real connections during tests
  # Tag a spec group with `:redis` to use the real $redis global variable
  config.before(:each) do |example|
    unless example.metadata[:redis]
      $redis = instance_double(Redis, get: nil, set: true, expire: true, del: true)
    end
  end
end

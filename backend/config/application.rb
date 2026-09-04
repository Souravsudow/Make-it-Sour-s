# Set up Gemfile path
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

# Set up gems listed in the Gemfile
require "bundler/setup"
require "bootsnap/setup" # Speed up boot time by caching expensive operations

# Only require the frameworks we need
require "action_controller/railtie"
require "action_view/railtie"
require "active_job/railtie"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile
Bundler.require(*Rails.groups)

module Backend
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version
    config.load_defaults 8.0

    # Autoload lib directory
    config.autoload_lib(ignore: %w[assets tasks])

    # Use Sidekiq as the ActiveJob queue adapter for persistent, retryable jobs
    config.active_job.queue_adapter = :sidekiq

    # Add Rack::Attack for rate limiting (insert after CORS, before app logic)
    config.middleware.use Rack::Attack

    # Configure timezone if needed
    # config.time_zone = "UTC"
  end
end

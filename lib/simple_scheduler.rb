require "active_job"
require "sidekiq/api"
require_relative "./simple_scheduler/scheduler_job"
require_relative "./simple_scheduler/task"
require_relative "./simple_scheduler/version"

# Module for scheduling jobs at specific times using Sidekiq.
module SimpleScheduler
  # Load the rake task into the Rails app
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(File.dirname(__FILE__), "tasks/simple_scheduler_tasks.rake")
    end
  end
end

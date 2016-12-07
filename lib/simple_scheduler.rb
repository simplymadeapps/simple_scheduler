require "active_job"
require "sidekiq/api"
require_relative "./simple_scheduler/future_job"
require_relative "./simple_scheduler/railtie"
require_relative "./simple_scheduler/scheduler_job"
require_relative "./simple_scheduler/task"
require_relative "./simple_scheduler/version"

# Module for scheduling jobs at specific times using Sidekiq.
module SimpleScheduler
end

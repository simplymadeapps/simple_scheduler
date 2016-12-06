require "active_job"
require "sidekiq/api"
require_relative "./simple_scheduler/scheduler_job"
require_relative "./simple_scheduler/task"
require_relative "./simple_scheduler/version"

# Module scheduling jobs at specific times using Sidekiq.
module SimpleScheduler
end

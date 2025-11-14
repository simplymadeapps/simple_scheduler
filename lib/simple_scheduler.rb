# frozen_string_literal: true

require "active_job"
require "sidekiq/api"
require_relative "simple_scheduler/at"
require_relative "simple_scheduler/future_job"
require_relative "simple_scheduler/railtie"
require_relative "simple_scheduler/scheduler_job"
require_relative "simple_scheduler/task"
require_relative "simple_scheduler/version"

# Module for scheduling jobs at specific times using Sidekiq.
module SimpleScheduler
  # Used by a Rails initializer to handle expired tasks.
  #   SimpleScheduler.expired_task do |exception|
  #     ExceptionNotifier.notify_exception(
  #       exception,
  #       data: {
  #         task:      exception.task.name,
  #         scheduled: exception.scheduled_time,
  #         actual:    exception.run_time
  #       }
  #     )
  #   end
  def self.expired_task(&block)
    expired_task_blocks << block
  end

  # Blocks that should be called when a task doesn't run because it has expired.
  # @return [Array]
  def self.expired_task_blocks
    @expired_task_blocks ||= []
  end
end

# frozen_string_literal: true

module SimpleScheduler
  # Active Job class that wraps the scheduled job and determines if the job
  # should still be run based on the scheduled time and when the job expires.
  class FutureJob < ActiveJob::Base
    # An error class that is raised if a job does not run because the run time is
    # too late when compared to the scheduled run time.
    # @!attribute run_time
    #   @return [Time] The actual run time
    # @!attribute scheduled_time
    #   @return [Time] The scheduled run time
    # @!attribute task
    #   @return [SimpleScheduler::Task] The expired task
    class Expired < StandardError
      attr_accessor :run_time, :scheduled_time, :task
    end

    rescue_from Expired, with: :handle_expired_task

    # Perform the future job as defined by the task.
    # @param task_params [Hash] The params from the scheduled task
    # @param scheduled_time [Integer] The epoch time for when the job was scheduled to be run
    def perform(task_params, scheduled_time)
      @task = Task.new(task_params)
      @scheduled_time = Time.at(scheduled_time).in_time_zone(@task.time_zone)
      raise Expired if expired?

      queue_task
    end

    # Delete all future jobs created by Simple Scheduler from the `Sidekiq::ScheduledSet`.
    def self.delete_all
      Task.scheduled_set.each do |job|
        job.delete if job.display_class == "SimpleScheduler::FutureJob"
      end
    end

    private

    # The duration between the scheduled run time and actual run time that
    # will cause the job to expire. Expired jobs will not be executed.
    # @return [ActiveSupport::Duration]
    def expire_duration
      split_duration = @task.expires_after.split(".")
      duration = split_duration[0].to_i
      duration_units = split_duration[1]
      duration.send(duration_units)
    end

    # Returns whether or not the job has expired based on the time
    # between the scheduled run time and the current time.
    # @return [Boolean]
    def expired?
      return false if @task.expires_after.blank?

      expire_duration.from_now(@scheduled_time) < Time.now.in_time_zone(@task.time_zone)
    end

    # Handle the expired task by passing the task and run time information
    # to a block that can be creating in a Rails initializer file.
    def handle_expired_task(exception)
      exception.run_time = Time.now.in_time_zone(@task.time_zone)
      exception.scheduled_time = @scheduled_time
      exception.task = @task

      SimpleScheduler.expired_task_blocks.each do |block|
        block.call(exception)
      end
    end

    # The name of the method used to queue the task's job or worker.
    # @return [Symbol]
    def perform_method
      if @task.job_class.included_modules.include?(Sidekiq::Worker)
        :perform_async
      else
        :perform_later
      end
    end

    # Queue the task with the scheduled time if the job allows.
    def queue_task
      if @task.job_class.instance_method(:perform).arity.zero?
        @task.job_class.send(perform_method)
      else
        @task.job_class.send(perform_method, @scheduled_time.to_i)
      end
    end
  end
end

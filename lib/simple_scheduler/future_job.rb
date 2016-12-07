module SimpleScheduler
  # Active Job class that wraps the scheduled job and determines if the job
  # should still be run based on the scheduled time and when the job expires.
  class FutureJob < ActiveJob::Base
    # Perform the future job as defined by the task.
    # @param task_params [Hash] The params from the scheduled task
    # @param scheduled_time [Integer] The epoch time for when the job was scheduled to be run
    def perform(task_params, scheduled_time)
      @task = Task.new(task_params)
      @scheduled_time = Time.at(scheduled_time).in_time_zone(@task.time_zone)
      return if expired?

      if @task.job_class.included_modules.include?(Sidekiq::Worker)
        queue_sidekiq_worker
      else
        queue_active_job
      end
    end

    # Returns whether or not the job has expired based on the time
    # between the scheduled run time and the current time.
    # @return [Boolean]
    def expired?
      return false if @task.expires_after.blank?
      expire_duration.from_now(@scheduled_time) < Time.now.in_time_zone(@task.time_zone)
    end

    private

    # The duration between the scheduled run time and actual run time that
    # will cause the job to expire. Expired jobs will not be executed.
    def expire_duration
      split_duration = @task.expires_after.split(".")
      duration = split_duration[0].to_i
      duration_units = split_duration[1]
      duration.send(duration_units)
    end

    # Queue the job for immediate execution using Active Job.
    def queue_active_job
      puts "QUEUE ACTIVE JOB"
      puts @task.job_class.instance_method(:perform).arity
      if @task.job_class.instance_method(:perform).arity > 0
        @task.job_class.perform_later(@scheduled_time)
      else
        @task.job_class.perform_later
      end
    end

    # Queue the job for immediate execution using Sidekiq.
    def queue_sidekiq_worker
      if @task.job_class.instance_method(:perform).arity > 0
        @task.job_class.perform_async(@scheduled_time)
      else
        @task.job_class.perform_async
      end
    end
  end
end

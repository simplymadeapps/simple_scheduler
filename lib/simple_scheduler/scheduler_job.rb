module SimpleScheduler
  # Active Job class that queues jobs defined in the config file.
  class SchedulerJob < ActiveJob::Base
    def perform
      load_config
      queue_future_jobs
    end

    private

    # Returns the path of the Simple Scheduler configuration file.
    # @return [String]
    def config_path
      ENV["SIMPLE_SCHEDULER_CONFIG"] || "config/simple_scheduler.yml"
    end

    # Load the global scheduler config from the YAML file.
    def load_config
      @config = YAML.safe_load(ERB.new(File.read(config_path)).result)
      @queue_ahead = @config["queue_ahead"] || Task::DEFAULT_QUEUE_AHEAD_MINUTES
      @queue_name = @config["queue_name"] || "default"
      @time_zone = @config["tz"] || Time.zone.tzinfo.name
      @config.delete("queue_ahead")
      @config.delete("queue_name")
      @config.delete("tz")
    end

    # Queue each of the future jobs into Sidekiq from the defined tasks.
    def queue_future_jobs
      tasks.each do |task|
        # Schedule the new run times using the future job wrapper.
        new_run_times = task.future_run_times - task.existing_run_times
        new_run_times.each do |time|
          SimpleScheduler::FutureJob.set(queue: @queue_name, wait_until: time)
                                    .perform_later(task.params, time.to_i)
        end
      end
    end

    # The array of tasks loaded from the config YAML.
    # @return [Array<SimpleScheduler::Task]
    def tasks
      @config.map do |task_name, options|
        task_params = options.symbolize_keys
        task_params[:queue_ahead] ||= @queue_ahead
        task_params[:name] = task_name
        task_params[:tz] ||= @time_zone
        Task.new(task_params)
      end
    end
  end
end

module SimpleScheduler
  # Active Job class that queues jobs defined in the config file.
  class SchedulerJob < ActiveJob::Base
    # Accepts a file path to read the scheduler configuration.
    # @param config_path [String]
    def perform(config_path = nil)
      config_path ||= "config/simple_scheduler.yml"
      load_config(config_path)
      queue_future_jobs
    end

    private

    # Load the global scheduler config from the YAML file.
    # @param config_path [String]
    def load_config(config_path)
      @config = YAML.load_file(config_path)
      @queue_ahead = @config["queue_ahead"] || Task::DEFAULT_QUEUE_AHEAD_MINUTES
      @time_zone = @config["tz"] || Time.zone.tzinfo.name
      @config.delete("queue_ahead")
      @config.delete("tz")
    end

    # Queue each of the future jobs into Sidekiq from the defined tasks.
    def queue_future_jobs
      tasks.each do |task|
        new_run_times = task.future_run_times - task.existing_run_times
        next if new_run_times.empty?

        # Schedule the new run times using the future job wrapper.
        new_run_times.each do |time|
          SimpleScheduler::FutureJob.set(wait_until: time).perform_later(task.params, time.to_i)
        end
      end
    end

    # The array of tasks loaded from the config YAML.
    # @return [Array<SimpleScheduler::SchedulerJob]
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

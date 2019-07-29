module SimpleScheduler
  # Class for parsing each task in the scheduler config YAML file and returning
  # the values needed to schedule the task in the future.
  #
  # @!attribute [r] job_class
  #   @return [Class] The class of the job or worker.
  # @!attribute [r] params
  #   @return [Hash] The params used to create the task
  class Task
    attr_reader :job_class, :params

    DEFAULT_QUEUE_AHEAD_MINUTES = 360

    # Initializes a task by parsing the params so the task can be queued in the future.
    # @param params [Hash]
    # @option params [String] :class The class of the Active Job or Sidekiq Worker
    # @option params [String] :every How frequently the job will be performed
    # @option params [String] :at The starting time for the interval
    # @option params [String] :expires_after The interval used to determine how late the job is allowed to run
    # @option params [Integer] :queue_ahead The number of minutes that jobs should be queued in the future
    # @option params [String] :task_name The name of the task as defined in the YAML config
    # @option params [String] :tz The time zone to use when parsing the `at` option
    def initialize(params)
      validate_params!(params)
      @params = params
    end

    # The task's first run time as a Time-like object.
    # @return [SimpleScheduler::At]
    def at
      @at ||= At.new(@params[:at], time_zone)
    end

    # The time between the scheduled and actual run time that should cause the job not to run.
    # @return [String]
    def expires_after
      @params[:expires_after]
    end

    # Returns an array of existing jobs matching the job class of the task.
    # @return [Array<Sidekiq::SortedEntry>]
    def existing_jobs
      @existing_jobs ||= SimpleScheduler::Task.scheduled_set.select do |job|
        next unless job.display_class == "SimpleScheduler::FutureJob"

        task_params = job.display_args[0].symbolize_keys
        task_params[:class] == job_class_name && task_params[:name] == name
      end.to_a
    end

    # Returns an array of existing future run times that have already been scheduled.
    # @return [Array<Time>]
    def existing_run_times
      @existing_run_times ||= existing_jobs.map(&:at)
    end

    # How often the job will be run.
    # @return [ActiveSupport::Duration]
    def frequency
      @frequency ||= parse_frequency(@params[:every])
    end

    # Returns an array Time objects for future run times based on
    # the current time and the given minutes to look ahead.
    # @return [Array<Time>]
    # rubocop:disable Metrics/AbcSize
    def future_run_times
      last_run_time = at - frequency
      last_run_time = last_run_time.in_time_zone(time_zone)
      future_run_times = []

      # Ensure there are at least two future jobs scheduled and that the queue ahead time is filled
      while (future_run_times + existing_run_times).length < 2 || minutes_queued_ahead(last_run_time) < queue_ahead
        last_run_time = frequency.from_now(last_run_time)
        # The hour may not match because of a shift caused by DST in previous run times,
        # so we need to ensure that the hour matches the specified hour if given.
        last_run_time = last_run_time.change(hour: at.hour, min: at.min) if at.hour?
        future_run_times << last_run_time unless existing_run_times.include?(last_run_time)
      end

      future_run_times
    end
    # rubocop:enable Metrics/AbcSize

    # The class name of the job or worker.
    # @return [String]
    def job_class_name
      @params[:class]
    end

    # The name of the task as defined in the YAML config.
    # @return [String]
    def name
      @params[:name]
    end

    # The number of minutes that jobs should be queued in the future.
    # @return [Integer]
    def queue_ahead
      @queue_ahead ||= @params[:queue_ahead] || DEFAULT_QUEUE_AHEAD_MINUTES
    end

    # The time zone to use when parsing the `at` option.
    # @return [ActiveSupport::TimeZone]
    def time_zone
      @time_zone ||= params[:tz] ? ActiveSupport::TimeZone.new(params[:tz]) : Time.zone
    end

    # Loads the scheduled jobs from Sidekiq once to avoid loading from
    # Redis for each task when looking up existing scheduled jobs.
    # @return [Sidekiq::ScheduledSet]
    def self.scheduled_set
      @scheduled_set ||= Sidekiq::ScheduledSet.new
    end

    private

    def minutes_queued_ahead(last_run_time)
      (last_run_time - Time.now) / 60
    end

    def parse_frequency(every_string)
      split_duration = every_string.split(".")
      frequency = split_duration[0].to_i
      frequency_units = split_duration[1]
      frequency.send(frequency_units)
    end

    def validate_params!(params)
      raise ArgumentError, "Missing param `class` specifying the class of the job to run." unless params.key?(:class)
      raise ArgumentError, "Missing param `every` specifying how often the job should run." unless params.key?(:every)

      @job_class = params[:class].constantize
      params[:name] ||= params[:class]
    end
  end
end

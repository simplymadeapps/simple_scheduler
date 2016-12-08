module SimpleScheduler
  # Class for parsing each task in the scheduler config YAML file and returning
  # the values needed to schedule the task in the future.
  #
  # @!attribute [r] at
  #   @return [String] The starting time for the interval
  # @!attribute [r] expires_after
  #   @return [String] The time between the scheduled and actual run time that should cause the job not to run
  # @!attribute [r] frequency
  #   @return [ActiveSupport::Duration] How often the job will be run
  # @!attribute [r] job_class
  #   @return [Class] The class of the job or worker
  # @!attribute [r] job_class_name
  #   @return [String] The class name of the job or worker
  # @!attribute [r] name
  #   @return [String] The name of the task as defined in the YAML config
  # @!attribute [r] params
  #   @return [Hash] The params used to create the task
  # @!attribute [r] queue_ahead
  #   @return [String] The name of the task as defined in the YAML config
  # @!attribute [r] time_zone
  #   @return [ActiveSupport::TimeZone] The time zone to use when parsing the `at` option
  class Task
    attr_reader :at, :expires_after, :frequency, :job_class, :job_class_name
    attr_reader :name, :params, :queue_ahead, :time_zone

    AT_PATTERN = /(Sun|Mon|Tue|Wed|Thu|Fri|Sat)?\s?(?:\*{1,2}|(\d{1,2})):(\d{1,2})/
    DAYS = %w(Sun Mon Tue Wed Thu Fri Sat).freeze
    DEFAULT_QUEUE_AHEAD_MINUTES = 360

    # Initializes a task by parsing the params so the task can be queued in the future.
    # @param params [Hash]
    # @option params [String] :class The class of the Active Job or Sidekiq Worker
    # @option params [String] :every How frequently the job will be performed
    # @option params [String] :at The starting time for the interval
    # @option params [String] :expires_after The time between the scheduled and actual run time that should cause the job not to run
    # @option params [Integer] :queue_ahead The number of minutes that jobs should be queued in the future
    # @option params [String] :task_name The name of the task as defined in the YAML config
    # @option params [String] :tz The time zone to use when parsing the `at` option
    def initialize(params)
      validate_params!(params)
      @at             = params[:at]
      @expires_after  = params[:expires_after]
      @frequency      = parse_frequency(params[:every])
      @job_class_name = params[:class]
      @job_class      = @job_class_name.constantize
      @queue_ahead    = params[:queue_ahead] || DEFAULT_QUEUE_AHEAD_MINUTES
      @name           = params[:name]
      @params         = params
      @time_zone      = params[:tz] ? ActiveSupport::TimeZone.new(params[:tz]) : Time.zone
    end

    # Returns an array of existing jobs matching the job class of the task.
    # @return [Array<Sidekiq::SortedEntry>]
    def existing_jobs
      @existing_jobs ||= SimpleScheduler::Task.scheduled_set.select do |job|
        next unless job.display_class == "SimpleScheduler::FutureJob"
        task_params = job.display_args[0]
        task_params["class"] == job_class_name && task_params["name"] == name
      end.to_a
    end

    # Returns an array of existing future run times that have already been scheduled.
    # @return [Array<Time>]
    def existing_run_times
      @existing_run_times ||= existing_jobs.map(&:at)
    end

    # Returns the very first time a job should be run for the scheduled task.
    # @return [Time]
    def first_run_time
      first_run_time = first_run_day
      change_hour = first_run_hour
      change_hour += 1 if run_next_hour?
      first_run_time = first_run_time.change(hour: change_hour, min: first_run_min)
      first_run_time += first_run_wday? ? 1.week : 1.day if now > first_run_time
      first_run_time
    end

    # Returns an array Time objects for future run times based on
    # the current time and the given minutes to look ahead.
    # @return [Array<Time>]
    def future_run_times
      future_run_times = existing_run_times.dup
      last_run_time = future_run_times.last || first_run_time - frequency
      last_run_time = last_run_time.in_time_zone(time_zone)

      # Ensure there are at least two future jobs scheduled and that the queue ahead time is filled
      while future_run_times.length < 2 || ((last_run_time - now) / 1.minute) < queue_ahead
        last_run_time = frequency.from_now(last_run_time)
        last_run_time = last_run_time.change(hour: first_run_hour, min: first_run_min) if first_run_hour?
        future_run_times << last_run_time
      end

      future_run_times
    end

    # Loads the scheduled jobs from Sidekiq once to avoid loading from
    # Redis for each task when looking up existing scheduled jobs.
    # @return [Sidekiq::ScheduledSet]
    def self.scheduled_set
      @scheduled_set ||= Sidekiq::ScheduledSet.new
    end

    private

    def at_match
      @at_match ||= AT_PATTERN.match(@at) || []
    end

    def first_run_day
      return @first_run_day if @first_run_day

      @first_run_day = now.beginning_of_day

      # If no day of the week is given, return today
      return @first_run_day unless first_run_wday

      # Shift to the correct day of the week if given
      add_days = first_run_wday - first_run_day.wday
      add_days += 7 if first_run_day.wday > first_run_wday
      @first_run_day += add_days.days
    end

    def first_run_hour
      @first_run_hour ||= (at_match[2] || now.hour).to_i
    end

    def first_run_hour?
      at_match[2].present?
    end

    def first_run_min
      @first_run_min ||= (at_match[3] || now.min).to_i
    end

    def first_run_wday
      @first_run_wday ||= DAYS.index(at_match[1])
    end

    def first_run_wday?
      at_match[1].present?
    end

    def now
      @now ||= @time_zone.now.beginning_of_minute
    end

    def parse_frequency(every_string)
      split_duration = every_string.split(".")
      frequency = split_duration[0].to_i
      frequency_units = split_duration[1]
      frequency.send(frequency_units)
    end

    def run_next_hour?
      !first_run_hour? && first_run_hour == now.hour && first_run_min < now.min
    end

    def validate_params!(params)
      params[:name] ||= params[:class]
      raise ArgumentError, "Missing param `class` specifying the class of the job to run." unless params.key?(:class)
      raise ArgumentError, "Missing param `every` specifying how often the job should run." unless params.key?(:every)
    end
  end
end

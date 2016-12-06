module SimpleScheduler
  # Class for parsing each task in the scheduler config YAML file and returning
  # the values needed to schedule the task in the future.
  class Task
    attr_accessor :at, :frequency, :job_class, :job_class_name, :name, :queue_ahead, :time_zone

    AT_PATTERN = /(Sun|Mon|Tue|Wed|Thu|Fri|Sat)?\s?(?:\*{1,2}|(\d{1,2})):(\d{1,2})/
    DAYS = %w(Sun Mon Tue Wed Thu Fri Sat).freeze
    DEFAULT_QUEUE_AHEAD_MINUTES = 360

    # Initializes a task by parsing the params so the task can be queued in the future.
    # @param params [Hash]
    # @option params [String] :class The class of the Active Job or Sidekiq Worker
    # @option params [String] :every How frequently the job will be performed
    # @option params [String] :at The starting time for the interval
    # @option params [Integer] :queue_ahead The number of minutes that jobs should be queued in the future
    # @option params [String] :task_name The name of the task as defined in the YAML config
    # @option params [ActiveSupport::TimeZone] :tz The time zone to use when parsing the `at` option
    def initialize(params)
      validate_params!(params)
      @at = params[:at]
      @frequency = parse_frequency(params[:every])
      @job_class_name = params[:class]
      @job_class = @job_class_name.constantize
      @queue_ahead = params[:queue_ahead] || DEFAULT_QUEUE_AHEAD_MINUTES
      @name = params[:name] || @job_class_name
      @time_zone = params[:tz] || Time.zone
    end

    # Returns an array of existing jobs matching the job class of the task.
    # @return [Array<Sidekiq::SortedEntry>]
    def existing_jobs
      @existing_jobs ||= SimpleScheduler::Task.scheduled_set.select do |job|
        job.display_class == @job_class_name
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
      change_hour += 1 if at_match[2].nil? && first_run_hour == now.hour && first_run_min < now.min
      first_run_time = first_run_time.change(hour: change_hour, min: first_run_min)
      first_run_time += at_match[1] ? 1.week : 1.day if now > first_run_time
      first_run_time
    end

    # Returns an array Time objects for future run times based on
    # the current time and the given minutes to look ahead.
    # @return [Array<Time>]
    def future_run_times
      future_run_times = existing_run_times.dup
      last_run_time = future_run_times.last || first_run_time - frequency
      last_run_time = last_run_time.in_time_zone(@time_zone)

      while future_run_times.length < 2 || ((last_run_time - now) / 1.minute) < @queue_ahead
        last_run_time = frequency.from_now(last_run_time)
        last_run_time = last_run_time.change(hour: first_run_hour, min: first_run_min) if at_match[2]
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

    def first_run_min
      @first_run_min ||= (at_match[3] || now.min).to_i
    end

    def first_run_wday
      @first_run_wday ||= DAYS.index(at_match[1])
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

    def validate_params!(params)
      raise ArgumentError, "Missing param `class` specifying the class of the job to run." unless params.key?(:class)
      raise ArgumentError, "Missing param `every` specifying how often the job should run." unless params.key?(:every)
    end
  end
end

# Simple Scheduler

[![Build Status](https://travis-ci.org/simplymadeapps/simple_scheduler.svg?branch=master)](https://travis-ci.org/simplymadeapps/simple_scheduler)
[![Code Climate](https://codeclimate.com/github/simplymadeapps/simple_scheduler/badges/gpa.svg)](https://codeclimate.com/github/simplymadeapps/simple_scheduler)
[![Test Coverage](https://codeclimate.com/github/simplymadeapps/simple_scheduler/badges/coverage.svg)](https://codeclimate.com/github/simplymadeapps/simple_scheduler/coverage)
[![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](http://www.rubydoc.info/github/simplymadeapps/simple_scheduler/)

Simple Scheduler is a scheduling add-on that is designed to be used with
[Sidekiq](http://sidekiq.org) and
[Heroku Scheduler](https://elements.heroku.com/addons/scheduler). It
gives you the ability to **schedule tasks at any interval** without adding
a clock process. Heroku Scheduler only allows you to schedule tasks every 10 minutes,
every hour, or every day.

## Production Ready?

**Yes.** We are using Simple Scheduler in production for scheduling tasks that run
hourly, nightly, weekly, and every 10 minutes in [Simple In/Out](https://www.simpleinout.com).

### Why did we need to create yet another job scheduler?

Every option we evaluated seems to have the same flaw: **If your server is down, your job won't run.**

[Check out our intro blog post to learn more](http://www.simplymadeapps.com/blog/2017/01/simple-scheduler-schedule-recurring-tasks-to-run-at-any-interval/).

## Requirements

You must be using:

- Rails 4.2+
- ActiveJob
- [Sidekiq](http://sidekiq.org)
- [Heroku Scheduler](https://elements.heroku.com/addons/scheduler)

Both Active Job and Sidekiq::Worker classes can be queued by the scheduler.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "simple_scheduler"
```

And then execute:

```bash
$ bundle
```

## Getting Started

### Create the Configuration File

Create the file `config/simple_scheduler.yml` in your Rails project:

```yml
# Global configuration options. These can also be set on each task.
queue_ahead: 360 # Number of minutes to queue jobs into the future
queue_name: "default" # The Sidekiq queue name used by SimpleScheduler::FutureJob
tz: "America/Chicago" # The application time zone will be used by default if not set

# Runs once every 2 minutes
simple_task:
  class: "SomeActiveJob"
  every: "2.minutes"

# Runs once every day at 4:00 AM. The job will expire after 23 hours, which means the
# job will not run if 23 hours passes (server downtime) before the job is actually run
overnight_task:
  class: "SomeSidekiqWorker"
  every: "1.day"
  at: "4:00"
  expires_after: "23.hours"

# Runs once every half hour, starting on the 30 min mark
half_hour_task:
  class: "HalfHourTask"
  every: "30.minutes"
  at: "*:30"

# Runs once every week on Saturdays at 12:00 AM
weekly_task:
  class: "WeeklyJob"
  every: "1.week"
  at: "Sat 0:00"
  tz: "America/New_York"
```

### Set up Heroku Scheduler

Add the rake task to Heroku Scheduler and set it to run every 10 minutes:

```
rake simple_scheduler
```

![Heroku Scheduler](https://cloud.githubusercontent.com/assets/124570/21104523/6d733d1a-c04c-11e6-89af-590e7d234cdf.gif)

It may be useful to point to a specific configuration file in non-production environments.
Use a custom configuration file by setting the `SIMPLE_SCHEDULER_CONFIG` environment variable.

```
SIMPLE_SCHEDULER_CONFIG=config/simple_scheduler.staging.yml
```

### Task Options

#### :class

The class name of the ActiveJob or Sidekiq::Worker. Your job or
worker class should accept the expected run time as a parameter
on the `perform` method.

#### :every

How frequently the task should be performed as an ActiveSupport duration definition.

```yml
"1.day"
"5.days"
"12.hours"
"20.minutes"
"1.week"
```

#### :at (optional)

This is the starting point\* for the `:every` duration. If not given, the job will
run immediately when the configuration file is loaded for the first time and will
follow the `:every` duration to determine future execution times.

Valid string formats/examples:

```yml
"18:00"
"3:30"
"**:00"
"*:30"
"Sun 2:00" # [Sun|Mon|Tue|Wed|Thu|Fri|Sat]
```

\* If you specify the hour of the day the job should run, it will only run in that hour,
so if you specify an `:every` duration of less than `1.day`, the job will only run
when the run time hour matches the `:at` time's hour.
See [#17](https://github.com/simplymadeapps/simple_scheduler/issues/17) for more info.

#### :expires_after (optional)

If your worker process is down for an extended period of time, you may not want certain jobs
to execute when the server comes back online. The `:expires_after` value will be used
to determine if it's too late to run the job at the actual run time.

All jobs are scheduled in the future using the `SimpleScheduler::FutureJob`. This
wrapper job does the work of evaluating the current time and determining if the
scheduled job should run. See [Handling Expired Jobs](#handling-expired-jobs).

The string should be in the form of an ActiveSupport duration.

```yml
"59.minutes"
"23.hours"
```

#### :queue_ahead (optional)

The `:queue_ahead` is the number of minutes that the job should be scheduled into the future.
The default value is `360`, so Simple Scheduler will make sure you have scheduled jobs for
the next 6 hours. This allows for a major outage without losing track of jobs that were
supposed to run during that time.

**There are always a minimum of 2 scheduled jobs for each scheduled task.** This ensures there
is always one job in the queue that can be used to determine the next run time, even if one of
the two was executed during the 10 minute Heroku Scheduler wait time.

The `:queue_ahead` can be set as a global configuration option or for each individual task.

#### :tz (optional)

Use `:tz` to specify the time zone of your `:at` time. If no time zone is specified, the Time.zone
default in your Rails app will be used when parsing the `:at` time. A list of all the available
timezone identifiers can be obtained using `TZInfo::Timezone.all_identifiers`.

The `:tz` can be set as a global configuration option or for each individual task.

## Writing Your Jobs

There is no guarantee that the job will run at the exact time given in the
configuration, so the time the job was scheduled to run will be passed to
the job. This allows you to handle situations where the current time doesn't
match the time it was expected to run. The `scheduled_time` argument is optional.

```ruby
class ExampleJob < ActiveJob::Base
  # @param scheduled_time [Integer] The epoch time for when the job was scheduled to be run
  def perform(scheduled_time)
    puts Time.at(scheduled_time)
  end
end
```

#### Determine if the Job Should Run

Simple Scheduler doesn't support specifying multiple days of the week or a specific day of the month.
You can use the `scheduled_time` with a guard clause to ensure the job only runs on specific days.

Set up the jobs to run every day, even though we don't actually want them to run every day:

```yml
# config/simple_scheduler.yml
payroll:
  class: "PayrollJob"
  every: "1.day"
  at: "0:00"

weekday_reports:
  class: "WeekdayReportsJob"
  every: "1.day"
  at: "18:00"
```

Use a guard clause in each of our jobs to exit the job if it shouldn't run that day:

```ruby
# A job that runs only on the 1st and 15th of the month.
class PayrollJob < ActiveJob::Base
  # @param scheduled_time [Integer] The epoch time for when the job was scheduled to be run
  def perform(scheduled_time)
    # Exit the job unless it's the 1st or 15th day of the month
    day_of_the_month = Time.at(scheduled_time).day
    return unless day_of_the_month == 1 || day_of_the_month == 15

    # Perform the job...
  end
end

# A job that runs only on weekdays, Monday - Friday.
class WeekdayReportsJob < ActiveJob::Base
  # @param scheduled_time [Integer] The epoch time for when the job was scheduled to be run
  def perform(scheduled_time)
    # Exit the job unless it's Monday (1), Tuesday (2), Wednesday (3), Thursday (4), or Friday (5)
    day_of_the_week = Time.at(scheduled_time).wday
    return unless (1..5).include?(day_of_the_week)

    # Perform the job...
  end
end
```

## Handling Expired Jobs

If you assign the `:expires_after` option to your task, you may want to know if
a job wasn't run because it expires. Add this block to an initializer file:

```ruby
# config/initializers/simple_scheduler.rb

# Block for handling an expired task from Simple Scheduler
# @param exception [SimpleScheduler::FutureJob::Expired]
# @see http://www.rubydoc.info/github/simplymadeapps/simple_scheduler/master/SimpleScheduler/FutureJob/Expired
SimpleScheduler.expired_task do |exception|
  ExceptionNotifier.notify_exception(
    exception,
    data: {
      task:      exception.task.name,
      scheduled: exception.scheduled_time,
      actual:    exception.run_time
    }
  )
end
```

## Making Changes to Configuration File

Any changes made to the YAML configuration file will be picked up by Simple Scheduler
the next time `rake simple_scheduler` is run. Depending on the changes, you may need
to reset the current job queue.

Reasons you may need to reset the job queue:

- Renaming a job's class
- Deleting a scheduled task
- Changing the task's run time interval
- Changing the day of the week the job is run

A rake task exists to delete all existing scheduled jobs and queue them back up from scratch:

```
rake simple_scheduler:reset
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

## License
The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

require "rails_helper"

describe SimpleScheduler::Task, type: :model do
  class SimpleSchedulerTestJob < ActiveJob::Base
    def perform(task_name, time)
    end
  end

  describe "initialize" do
    it "requires the `class` param" do
      expect do
        described_class.new(every: "10.minutes")
      end.to raise_error(ArgumentError, "Missing param `class` specifying the class of the job to run.")
    end

    it "requires the `every` param" do
      expect do
        described_class.new(class: "SimpleSchedulerTestJob")
      end.to raise_error(ArgumentError, "Missing param `every` specifying how often the job should run.")
    end
  end

  describe "existing_jobs" do
    let(:task) do
      described_class.new(
        class: "SimpleSchedulerTestJob",
        every: "1.hour"
      )
    end

    it "returns an array of Sidekiq entries for existing jobs" do
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(nil, nil, "wrapped" => "SimpleSchedulerTestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"),
        Sidekiq::SortedEntry.new(nil, nil, "wrapped" => "SimpleSchedulerTestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
      ])
      expect(task.existing_jobs.length).to eq(2)
    end

    it "only returns Sidekiq entries for the task's job class" do
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(nil, nil, "wrapped" => "SimpleSchedulerTestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"),
        Sidekiq::SortedEntry.new(nil, nil, "wrapped" => "SomeOtherJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
      ])
      expect(task.existing_jobs.length).to eq(1)
    end

    it "returns an empty array if there are no existing jobs" do
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(nil, nil, "wrapped" => "SomeOtherJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"),
        Sidekiq::SortedEntry.new(nil, nil, "wrapped" => "SomeOtherJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
      ])
      expect(task.existing_jobs.length).to eq(0)
    end
  end

  describe "existing_run_times" do
    let(:task) do
      described_class.new(
        class: "SimpleSchedulerTestJob",
        every: "1.hour"
      )
    end

    it "returns an array of existing future run times for the task's job" do
      future_time1 = (Time.now + 1.hour).beginning_of_minute
      future_time2 = (Time.now + 2.hours).beginning_of_minute
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(nil, future_time1.to_i, "wrapped" => "SimpleSchedulerTestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"),
        Sidekiq::SortedEntry.new(nil, future_time2.to_i, "wrapped" => "SimpleSchedulerTestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
      ])
      expect(task.existing_run_times).to eq([future_time1, future_time2])
    end

    it "only returns times for the task's job class" do
      future_time1 = (Time.now + 1.hour).beginning_of_minute
      future_time2 = (Time.now + 2.hours).beginning_of_minute
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(nil, future_time1.to_i, "wrapped" => "SimpleSchedulerTestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"),
        Sidekiq::SortedEntry.new(nil, future_time2.to_i, "wrapped" => "SomeOtherJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
      ])
      expect(task.existing_run_times).to eq([future_time1])
    end

    it "returns an empty array if there are no times" do
      future_time1 = (Time.now + 1.hour).beginning_of_minute
      future_time2 = (Time.now + 2.hours).beginning_of_minute
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(nil, future_time1.to_i, "wrapped" => "SomeOtherJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper"),
        Sidekiq::SortedEntry.new(nil, future_time2.to_i, "wrapped" => "SomeOtherJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
      ])
      expect(task.existing_run_times).to eq([])
    end
  end

  describe "first_run_time" do
    context "when the run :at time includes a specific hour" do
      let(:task) do
        described_class.new(
          class: "SimpleSchedulerTestJob",
          every: "1.day",
          at:    "2:30",
          tz:    ActiveSupport::TimeZone.new("America/Chicago")
        )
      end

      context "when the :at hour is after the current time's hour" do
        it "returns the :at hour:minutes on the current day" do
          Timecop.freeze(Time.parse("2016-12-02 1:23:45 CST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-02 2:30:00 CST"))
          end
        end
      end

      context "when the :at hour is before the current time's hour" do
        it "returns the :at hour:minutes on the next day" do
          Timecop.freeze(Time.parse("2016-12-02 3:45:12 CST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-03 2:30:00 CST"))
          end
        end
      end

      context "when the :at hour is the same as the current time's hour" do
        it "returns the :at hour:minutes on the next day if the :at minute < current time's min" do
          Timecop.freeze(Time.parse("2016-12-02 2:34:56 CST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-03 2:30:00 CST"))
          end
        end

        it "returns the :at hour:minutes on the current day if the :at minute > current time's min" do
          Timecop.freeze(Time.parse("2016-12-02 2:20:00 CST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-02 2:30:00 CST"))
          end
        end

        it "returns the :at hour:minutes without seconds on the current day if the :at minute == current time's min" do
          Timecop.freeze(Time.parse("2016-12-02 2:30:30 CST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-02 2:30:00 CST"))
          end
        end
      end

      context "when a specific day of the week is given" do
        let(:task) do
          described_class.new(
            class: "SimpleSchedulerTestJob",
            every: "1.week",
            at:    "Fri 23:45",
            tz:    ActiveSupport::TimeZone.new("America/Chicago")
          )
        end

        context "if the current day is earlier in the week than the :at day" do
          it "returns the next day the :at day occurs" do
            Timecop.freeze(Time.parse("2016-12-01 1:23:45 CST")) do # Dec 1 is Thursday
              expect(task.first_run_time).to eq(Time.parse("2016-12-02 23:45:00 CST"))
            end
          end
        end

        context "if the current day is later in the week than the :at day" do
          it "returns the next day the :at day occurs, which will be next week" do
            Timecop.freeze(Time.parse("2016-12-03 1:23:45 CST")) do # Dec 3 is Saturday
              expect(task.first_run_time).to eq(Time.parse("2016-12-09 23:45:00 CST"))
            end
          end
        end

        context "if the current day is the same as the :at day" do
          it "returns the current day if :at time is later than the current time" do
            Timecop.freeze(Time.parse("2016-12-02 23:20:00 CST")) do # Dec 2 is Friday
              expect(task.first_run_time).to eq(Time.parse("2016-12-02 23:45:00 CST"))
            end
          end

          it "returns next week's day if :at time is earlier than the current time" do
            Timecop.freeze(Time.parse("2016-12-02 23:50:00 CST")) do # Dec 2 is Friday
              expect(task.first_run_time).to eq(Time.parse("2016-12-09 23:45:00 CST"))
            end
          end

          it "returns the current time without seconds if :at time matches the current time" do
            Timecop.freeze(Time.parse("2016-12-02 23:45:45 CST")) do # Dec 2 is Friday
              expect(task.first_run_time).to eq(Time.parse("2016-12-02 23:45:00 CST"))
            end
          end
        end
      end
    end

    context "when the run :at time allows any hour" do
      let(:task) do
        described_class.new(
          class: "SimpleSchedulerTestJob",
          every: "1.hour",
          at:    "*:30",
          tz:    ActiveSupport::TimeZone.new("America/New_York")
        )
      end

      context "when the :at minute < current time's min" do
        it "returns the next hour with the :at minutes on the current day" do
          Timecop.freeze(Time.parse("2016-12-02 2:45:00 EST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-02 3:30:00 EST"))
          end
        end
      end

      context "when the :at minute > current time's min" do
        it "returns the current hour with the :at minutes on the current day" do
          Timecop.freeze(Time.parse("2016-12-02 2:25:25 EST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-02 2:30:00 EST"))
          end
        end
      end

      context "when the :at minute == current time's min" do
        it "returns the current time without seconds" do
          Timecop.freeze(Time.parse("2016-12-02 2:30:25 EST")) do
            expect(task.first_run_time).to eq(Time.parse("2016-12-02 2:30:00 EST"))
          end
        end
      end
    end

    context "when the run :at time isn't given" do
      let(:task) do
        described_class.new(
          class: "SimpleSchedulerTestJob",
          every: "1.hour",
          tz:    ActiveSupport::TimeZone.new("America/Los_Angeles")
        )
      end

      it "returns the current time, but drops the seconds" do
        Timecop.freeze(Time.parse("2016-12-02 1:23:45 PST")) do
          expect(task.first_run_time).to eq(Time.parse("2016-12-02 1:23:00 PST"))
        end
      end
    end
  end

  describe "future_run_times" do
    context "when creating a weekly task" do
      let(:task) do
        described_class.new(
          class:       "SimpleSchedulerTestJob",
          every:       "1.week",
          at:          "0:00",
          queue_ahead: 10,
          tz:          ActiveSupport::TimeZone.new("America/Chicago")
        )
      end

      it "returns at least the next two future times the job should be run" do
        Timecop.freeze(Time.parse("2016-12-01 1:00:00 CST")) do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-02 0:00:00 CST"),
            Time.parse("2016-12-09 0:00:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        Timecop.freeze(Time.parse("2016-12-01 20:00:00 CST")) do
          task.queue_ahead = 50400 # 5 weeks
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-02 0:00:00 CST"),
            Time.parse("2016-12-09 0:00:00 CST"),
            Time.parse("2016-12-16 0:00:00 CST"),
            Time.parse("2016-12-23 0:00:00 CST"),
            Time.parse("2016-12-30 0:00:00 CST"),
            Time.parse("2017-01-06 0:00:00 CST")
          ])
        end
      end
    end

    context "when creating a daily task" do
      let(:task) do
        described_class.new(
          class:       "SimpleSchedulerTestJob",
          every:       "1.day",
          at:          "00:30",
          queue_ahead: 10,
          tz:          ActiveSupport::TimeZone.new("America/Chicago")
        )
      end

      it "returns at least the next two future times the job should be run" do
        Timecop.freeze(Time.parse("2016-12-01 1:00:00 CST")) do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-02 0:30:00 CST"),
            Time.parse("2016-12-03 0:30:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        Timecop.freeze(Time.parse("2016-12-01 20:00:00 CST")) do
          task.queue_ahead = 10080 # 1 week
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-02 0:30:00 CST"),
            Time.parse("2016-12-03 0:30:00 CST"),
            Time.parse("2016-12-04 0:30:00 CST"),
            Time.parse("2016-12-05 0:30:00 CST"),
            Time.parse("2016-12-06 0:30:00 CST"),
            Time.parse("2016-12-07 0:30:00 CST"),
            Time.parse("2016-12-08 0:30:00 CST"),
            Time.parse("2016-12-09 0:30:00 CST")
          ])
        end
      end
    end

    context "when creating an hourly task" do
      let(:task) do
        described_class.new(
          class:       "SimpleSchedulerTestJob",
          every:       "1.hour",
          at:          "*:00",
          queue_ahead: 10,
          tz:          ActiveSupport::TimeZone.new("America/Chicago")
        )
      end

      it "returns at least the next two future times the job should be run" do
        Timecop.freeze(Time.parse("2016-12-01 1:00:00 CST")) do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-01 1:00:00 CST"),
            Time.parse("2016-12-01 2:00:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        Timecop.freeze(Time.parse("2016-12-01 20:00:00 CST")) do
          task.queue_ahead = 360 # 6 hours
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-01 20:00:00 CST"),
            Time.parse("2016-12-01 21:00:00 CST"),
            Time.parse("2016-12-01 22:00:00 CST"),
            Time.parse("2016-12-01 23:00:00 CST"),
            Time.parse("2016-12-02 0:00:00 CST"),
            Time.parse("2016-12-02 1:00:00 CST"),
            Time.parse("2016-12-02 2:00:00 CST")
          ])
        end
      end
    end

    context "when creating a frequent task" do
      let(:task) do
        described_class.new(
          class:       "SimpleSchedulerTestJob",
          every:       "15.minutes",
          at:          "*:00",
          queue_ahead: 5,
          tz:          ActiveSupport::TimeZone.new("America/Chicago")
        )
      end

      it "returns at least the next two future times the job should be run" do
        Timecop.freeze(Time.parse("2016-12-01 1:00:00 CST")) do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-01 1:00:00 CST"),
            Time.parse("2016-12-01 1:15:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        Timecop.freeze(Time.parse("2016-12-01 20:00:00 CST")) do
          task.queue_ahead = 60 # minutes
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-01 20:00:00 CST"),
            Time.parse("2016-12-01 20:15:00 CST"),
            Time.parse("2016-12-01 20:30:00 CST"),
            Time.parse("2016-12-01 20:45:00 CST"),
            Time.parse("2016-12-01 21:00:00 CST")
          ])
        end
      end
    end

    context "when daylight savings time falls back" do
      context "if the :at hour is given" do
        let(:task) do
          described_class.new(
            class: "SimpleSchedulerTestJob",
            every: "1.day",
            at:    "01:30",
            tz:    ActiveSupport::TimeZone.new("America/Chicago")
          )
        end

        it "will be scheduled to run at the given time" do
          Timecop.freeze(Time.parse("2016-11-06 00:00:00 CDT")) do
            expect(task.future_run_times).to include(Time.parse("2016-11-06 01:30:00 CDT"))
          end
        end

        it "won't be rescheduled when the time falls back if the job was previously executed" do
          Timecop.freeze(Time.parse("2016-11-06 01:00:00 CST")) do
            tomorrows_run_time = Time.parse("2016-11-07 01:30:00 CST")
            expect(task).to receive(:existing_jobs).and_return([
              Sidekiq::SortedEntry.new(nil, tomorrows_run_time.to_i, "wrapped" => "SimpleSchedulerTestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
            ])
            expect(task.future_run_times).to eq([
              Time.parse("2016-11-07 01:30:00 CST"),
              Time.parse("2016-11-08 01:30:00 CST")
            ])
          end
        end
      end

      context "if the :at hour isn't given" do
        let(:task) do
          described_class.new(
            class:       "SimpleSchedulerTestJob",
            every:       "1.hour",
            at:          "*:30",
            queue_ahead: 360,
            tz:          ActiveSupport::TimeZone.new("America/Chicago")
          )
        end

        it "will be scheduled to run every time based on the given frequency, including running twice at the 'same' hour" do
          Timecop.freeze(Time.parse("2016-11-06 00:00:00 CDT")) do
            expect(task.future_run_times).to eq([
              Time.parse("2016-11-06 00:30:00 CDT"),
              Time.parse("2016-11-06 01:30:00 CDT"),
              Time.parse("2016-11-06 01:30:00 CST"),
              Time.parse("2016-11-06 02:30:00 CST"),
              Time.parse("2016-11-06 03:30:00 CST"),
              Time.parse("2016-11-06 04:30:00 CST"),
              Time.parse("2016-11-06 05:30:00 CST")
            ])
          end
        end
      end
    end

    context "when daylight savings time springs forward" do
      context "if the :at hour is given" do
        let(:task) do
          described_class.new(
            class: "SimpleSchedulerTestJob",
            every: "1.day",
            at:    "02:30",
            tz:    ActiveSupport::TimeZone.new("America/Chicago")
          )
        end

        it "will always run, even if the time doesn't exist on the day" do
          Timecop.freeze(Time.parse("2016-03-13 01:00:00 CST")) do
            expect(task.future_run_times).to include(Time.parse("2016-03-13 02:30:00 CST"))
          end
        end

        it "won't throw off the hour it is run next time after running late" do
          Timecop.freeze(Time.parse("2016-03-13 01:00:00 CST")) do
            expect(task.future_run_times).to eq([
              Time.parse("2016-03-13 03:30:00 CDT"),
              Time.parse("2016-03-14 02:30:00 CDT")
            ])
          end
        end
      end

      context "if the :at hour isn't given" do
        let(:task) do
          described_class.new(
            class:       "SimpleSchedulerTestJob",
            every:       "1.hour",
            at:          "*:30",
            queue_ahead: 360,
            tz:          ActiveSupport::TimeZone.new("America/Chicago")
          )
        end

        it "will always run, even if the time doesn't exist on the day" do
          Timecop.freeze(Time.parse("2016-03-13 01:50:00 CST")) do
            expect(task.future_run_times).to include(Time.parse("2016-03-13 02:30:00 CST"))
          end
        end

        it "won't run twice or throw off the hour it is run next time" do
          Timecop.freeze(Time.parse("2016-03-13 00:50:00 CST")) do
            expect(task.future_run_times).to eq([
              Time.parse("2016-03-13 01:30:00 CST"),
              Time.parse("2016-03-13 03:30:00 CDT"),
              Time.parse("2016-03-13 04:30:00 CDT"),
              Time.parse("2016-03-13 05:30:00 CDT"),
              Time.parse("2016-03-13 06:30:00 CDT"),
              Time.parse("2016-03-13 07:30:00 CDT"),
              Time.parse("2016-03-13 08:30:00 CDT")
            ])
          end
        end
      end
    end
  end
end

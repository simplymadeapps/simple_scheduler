# frozen_string_literal: true

require "rails_helper"

describe SimpleScheduler::Task, type: :model do
  describe "initialize" do
    it "requires the `class` param" do
      expect do
        described_class.new(every: "10.minutes")
      end.to raise_error(ArgumentError, "Missing param `class` specifying the class of the job to run.")
    end

    it "requires the `every` param" do
      expect do
        described_class.new(class: "TestJob")
      end.to raise_error(ArgumentError, "Missing param `every` specifying how often the job should run.")
    end
  end

  describe "existing_jobs" do
    let(:task) do
      described_class.new(
        class: "TestJob",
        every: "1.hour",
        name: "test_task"
      )
    end

    let(:sidekiq_entry_matching_class_and_name) do
      Sidekiq::SortedEntry.new(
        nil,
        1,
        "wrapped" => "SimpleScheduler::FutureJob",
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "args" => [{ "arguments" => [{ "class" => "TestJob", "name" => "test_task" }] }]
      )
    end

    let(:sidekiq_entry_matching_class_wrong_task_name) do
      Sidekiq::SortedEntry.new(
        nil,
        1,
        "wrapped" => "SimpleScheduler::FutureJob",
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "args" => [{ "arguments" => [{ "class" => "TestJob", "name" => "wrong_task" }] }]
      )
    end

    let(:sidekiq_entry_wrong_class) do
      Sidekiq::SortedEntry.new(
        nil,
        1,
        "wrapped" => "SimpleScheduler::FutureJob",
        "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
        "args" => [{ "arguments" => [{ "class" => "SomeOtherJob", "name" => "test_task" }] }]
      )
    end

    it "returns an array of Sidekiq entries for existing jobs" do
      expect(described_class).to receive(:scheduled_set).and_return([
        sidekiq_entry_matching_class_and_name,
        sidekiq_entry_matching_class_and_name
      ])
      expect(task.existing_jobs.length).to eq(2)
    end

    it "only returns Sidekiq entries for the task's job class" do
      expect(described_class).to receive(:scheduled_set).and_return([
        sidekiq_entry_matching_class_and_name,
        sidekiq_entry_wrong_class
      ])
      expect(task.existing_jobs.length).to eq(1)
    end

    it "only returns Sidekiq entries for the task's name (key used for the YAML block)" do
      expect(described_class).to receive(:scheduled_set).and_return([
        sidekiq_entry_matching_class_and_name,
        sidekiq_entry_matching_class_wrong_task_name
      ])
      expect(task.existing_jobs.length).to eq(1)
    end

    it "returns an empty array if there are no existing jobs" do
      expect(described_class).to receive(:scheduled_set).and_return([
        sidekiq_entry_wrong_class,
        sidekiq_entry_wrong_class
      ])
      expect(task.existing_jobs.length).to eq(0)
    end
  end

  describe "existing_run_times" do
    let(:task) do
      described_class.new(
        class: "TestJob",
        every: "1.hour",
        name: "test_task"
      )
    end

    let(:future_time1) { (Time.now + 1.hour).beginning_of_minute }
    let(:future_time2) { (Time.now + 2.hours).beginning_of_minute }

    it "returns an array of existing future run times for the task's job" do
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(
          nil,
          future_time1.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "TestJob", "name" => "test_task" }] }]
        ),
        Sidekiq::SortedEntry.new(
          nil,
          future_time2.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "TestJob", "name" => "test_task" }] }]
        )
      ])
      expect(task.existing_run_times).to eq([future_time1, future_time2])
    end

    it "only returns times for the task's job class" do
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(
          nil,
          future_time1.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "TestJob", "name" => "test_task" }] }]
        ),
        Sidekiq::SortedEntry.new(
          nil,
          future_time2.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "SomeOtherJob", "name" => "test_task" }] }]
        )
      ])
      expect(task.existing_run_times).to eq([future_time1])
    end

    it "only returns times for the task's job class and task name" do
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(
          nil,
          future_time1.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "TestJob", "name" => "test_task" }] }]
        ),
        Sidekiq::SortedEntry.new(
          nil,
          future_time2.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "TestJob", "name" => "wrong_task" }] }]
        )
      ])
      expect(task.existing_run_times).to eq([future_time1])
    end

    it "returns an empty array if there are no times" do
      expect(described_class).to receive(:scheduled_set).and_return([
        Sidekiq::SortedEntry.new(
          nil,
          future_time1.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "SomeOtherJob", "name" => "test_task" }] }]
        ),
        Sidekiq::SortedEntry.new(
          nil,
          future_time2.to_i,
          "wrapped" => "SimpleScheduler::FutureJob",
          "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper",
          "args" => [{ "arguments" => [{ "class" => "SomeOtherJob", "name" => "test_task" }] }]
        )
      ])
      expect(task.existing_run_times).to eq([])
    end
  end

  describe "future_run_times" do
    context "when creating a weekly task" do
      let(:task) do
        described_class.new(
          class: "TestJob",
          every: "1.week",
          at: "0:00",
          queue_ahead: 10,
          tz: "America/Chicago"
        )
      end

      it "returns at least the next two future times the job should be run" do
        travel_to Time.parse("2016-12-01 1:00:00 CST") do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-02 0:00:00 CST"),
            Time.parse("2016-12-09 0:00:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        travel_to Time.parse("2016-12-01 20:00:00 CST") do
          task.instance_variable_set(:@queue_ahead, 50_400) # 5 weeks
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
          class: "TestJob",
          every: "1.day",
          at: "00:30",
          queue_ahead: 10,
          tz: "America/Chicago"
        )
      end

      it "returns at least the next two future times the job should be run" do
        travel_to Time.parse("2016-12-01 1:00:00 CST") do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-02 0:30:00 CST"),
            Time.parse("2016-12-03 0:30:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        travel_to Time.parse("2016-12-01 20:00:00 CST") do
          task.instance_variable_set(:@queue_ahead, 10_080) # 1 week
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
          class: "TestJob",
          every: "1.hour",
          at: "*:00",
          queue_ahead: 10,
          tz: "America/Chicago"
        )
      end

      it "returns at least the next two future times the job should be run" do
        travel_to Time.parse("2016-12-01 1:00:00 CST") do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-01 1:00:00 CST"),
            Time.parse("2016-12-01 2:00:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        travel_to Time.parse("2016-12-01 20:00:00 CST") do
          task.instance_variable_set(:@queue_ahead, 360) # 6 hours
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
          class: "TestJob",
          every: "15.minutes",
          at: "*:00",
          queue_ahead: 5,
          tz: "America/Chicago"
        )
      end

      it "returns at least the next two future times the job should be run" do
        travel_to Time.parse("2016-12-01 1:00:00 CST") do
          expect(task.future_run_times).to eq([
            Time.parse("2016-12-01 1:00:00 CST"),
            Time.parse("2016-12-01 1:15:00 CST")
          ])
        end
      end

      it "uses queue_ahead to ensure jobs are queued into the future" do
        travel_to Time.parse("2016-12-01 20:00:00 CST") do
          task.instance_variable_set(:@queue_ahead, 60) # minutes
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

    context "when daylight saving time falls back" do
      context "if the :at hour is given" do
        let(:task) do
          described_class.new(
            class: "TestJob",
            every: "1.day",
            at: "01:30",
            tz: "America/Chicago"
          )
        end

        it "will be scheduled to run at the given time" do
          travel_to Time.parse("2016-11-06 00:00:00 CDT") do
            expect(task.future_run_times).to include(Time.parse("2016-11-06 01:30:00 CDT"))
          end
        end

        it "won't be rescheduled when the time falls back if the job was previously executed" do
          travel_to Time.parse("2016-11-06 01:00:00 CST") do
            tomorrows_run_time = Time.parse("2016-11-07 01:30:00 CST")
            expect(task).to receive(:existing_jobs).and_return([
              Sidekiq::SortedEntry.new(nil, tomorrows_run_time.to_i, "wrapped" => "TestJob", "class" => "ActiveJob::QueueAdapters::SidekiqAdapter::JobWrapper")
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
            class: "TestJob",
            every: "1.hour",
            at: "*:30",
            queue_ahead: 360,
            tz: "America/Chicago"
          )
        end

        it "will be scheduled to run every time based on the given frequency, including running twice at the 'same' hour" do
          travel_to Time.parse("2016-11-06 00:00:00 CDT") do
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

    context "when daylight saving time springs forward" do
      context "if the :at hour is given" do
        let(:task) do
          described_class.new(
            class: "TestJob",
            every: "1.day",
            at: "02:30",
            tz: "America/Chicago"
          )
        end

        it "will always run, even if the time doesn't exist on the day" do
          travel_to Time.parse("2016-03-13 01:00:00 CST") do
            expect(task.future_run_times).to include(Time.parse("2016-03-13 02:30:00 CST"))
          end
        end

        it "won't throw off the hour it is run next time after running late" do
          travel_to Time.parse("2016-03-13 01:00:00 CST") do
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
            class: "TestJob",
            every: "1.hour",
            at: "*:30",
            queue_ahead: 360,
            tz: "America/Chicago"
          )
        end

        it "will always run, even if the time doesn't exist on the day" do
          travel_to Time.parse("2016-03-13 01:50:00 CST") do
            expect(task.future_run_times).to include(Time.parse("2016-03-13 02:30:00 CST"))
          end
        end

        it "won't run twice or throw off the hour it is run next time" do
          travel_to Time.parse("2016-03-13 00:50:00 CST") do
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

require "rails_helper"

describe SimpleScheduler::SchedulerJob, type: :job do
  let(:now) { Time.parse("2017-01-27 00:00:00 CST") }

  describe "successfully queues" do
    subject(:job) { described_class.perform_later }

    it "queues the job" do
      expect { job }.to change(enqueued_jobs, :size).by(1)
    end

    it "is in default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  describe "scheduling tasks without specifying a config path" do
    it "queues the jobs loaded from config/simple_scheduler.yml" do
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(4)
      end
    end
  end

  describe "loading a YML file with ERB tags" do
    it "parses the file and queues the jobs" do
      travel_to(now) do
        expect do
          described_class.perform_now("spec/simple_scheduler/config/erb_test.yml")
        end.to change(enqueued_jobs, :size).by(2)
      end
    end
  end

  describe "scheduling an hourly task" do
    it "queues jobs for at least six hours into the future by default" do
      travel_to(now) do
        expect do
          described_class.perform_now("spec/simple_scheduler/config/hourly_task.yml")
        end.to change(enqueued_jobs, :size).by(7)
      end
    end

    it "respects the queue_ahead global option" do
      travel_to(now) do
        expect do
          described_class.perform_now("spec/simple_scheduler/config/queue_ahead_global.yml")
        end.to change(enqueued_jobs, :size).by(3)
      end
    end

    it "respects the queue_ahead option per task" do
      travel_to(now) do
        expect do
          described_class.perform_now("spec/simple_scheduler/config/queue_ahead_per_task.yml")
        end.to change(enqueued_jobs, :size).by(4)
      end
    end
  end

  describe "scheduling a weekly task" do
    it "always queues two future jobs" do
      travel_to(now) do
        expect do
          described_class.perform_now("spec/simple_scheduler/config/active_job.yml")
        end.to change(enqueued_jobs, :size).by(2)
      end
    end
  end
end

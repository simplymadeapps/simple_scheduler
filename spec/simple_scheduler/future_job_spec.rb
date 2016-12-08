require "rails_helper"

describe SimpleScheduler::FutureJob, type: :job do
  describe "successfully queues" do
    subject(:job) { described_class.perform_later }

    it "queues the job" do
      expect { job }.to change(enqueued_jobs, :size).by(1)
    end

    it "is in default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end

  describe "when an Active Job is scheduled" do
    let(:task_params) do
      {
        class: "TestJob",
        every: "1.hour",
        name:  "job_task"
      }
    end

    it "queues the Active Job" do
      expect do
        described_class.perform_now(task_params, Time.now.to_i)
      end.to change(enqueued_jobs, :size).by(1)
    end
  end

  describe "when a Sidekiq Worker is scheduled" do
    let(:task_params) do
      {
        class: "TestWorker",
        every: "1.hour",
        name:  "worker_task"
      }
    end

    it "adds the job to the queue" do
      expect do
        described_class.perform_now(task_params, Time.now.to_i)
      end.to change(TestWorker.jobs, :size).by(1)
    end
  end

  describe "when a job or worker accepts the scheduled time as an argument" do
    it "executes an Active Job without exception" do
      expect do
        task_params = { class: "TestJob", every: "1.hour" }
        perform_enqueued_jobs do
          described_class.perform_now(task_params, Time.now.to_i)
        end
      end.not_to raise_error
    end

    it "executes an Sidekiq Worker without exception" do
      expect do
        task_params = { class: "TestWorker", every: "1.hour" }
        perform_enqueued_jobs do
          Sidekiq::Testing.inline! do
            described_class.perform_now(task_params, Time.now.to_i)
          end
        end
      end.not_to raise_error
    end
  end

  describe "when a job or worker accepts no arguments" do
    it "executes an Active Job without exception" do
      expect do
        task_params = { class: "TestNoArgsJob", every: "1.hour" }
        perform_enqueued_jobs do
          described_class.perform_now(task_params, Time.now.to_i)
        end
      end.not_to raise_error
    end

    it "executes an Sidekiq Worker without exception" do
      expect do
        task_params = { class: "TestNoArgsWorker", every: "1.hour" }
        perform_enqueued_jobs do
          Sidekiq::Testing.inline! do
            described_class.perform_now(task_params, Time.now.to_i)
          end
        end
      end.not_to raise_error
    end
  end

  describe "when the job is run within the allowed expiration time" do
    let(:task_params) do
      {
        class:         "TestJob",
        every:         "1.hour",
        name:          "job_task",
        expires_after: "30.minutes"
      }
    end

    it "adds the job to the queue" do
      expect do
        described_class.perform_now(task_params, (Time.now - 29.minutes).to_i)
      end.to change(enqueued_jobs, :size).by(1)
    end
  end

  describe "when the job is run past the allowed expiration time" do
    let(:task_params) do
      {
        class:         "TestJob",
        every:         "1.hour",
        name:          "job_task",
        expires_after: "30.minutes"
      }
    end

    it "doesn't add the job to the queue" do
      expect do
        described_class.perform_now(task_params, (Time.now - 31.minutes).to_i)
      end.to change(enqueued_jobs, :size).by(0)
    end
  end
end

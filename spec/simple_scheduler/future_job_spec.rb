require "rails_helper"
require "sidekiq/testing"
Sidekiq::Testing.fake!

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
        class: "SimpleSchedulerTestJob",
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
        class: "SimpleSchedulerTestWorker",
        every: "1.hour",
        name:  "worker_task"
      }
    end

    it "adds the job to the queue" do
      expect do
        described_class.perform_now(task_params, Time.now.to_i)
      end.to change(SimpleSchedulerTestWorker.jobs, :size).by(1)
    end
  end

  describe "when the job is run past the expired time" do
    let(:task_params) do
      {
        class: "SimpleSchedulerTestJob",
        every:         "1.hour",
        name:          "job_task",
        expires_after: "30.minutes"
      }
    end

    it "doesn't queue the job" do
      expect do
        described_class.perform_now(task_params, (Time.now - 31.minutes).to_i)
      end.to change(enqueued_jobs, :size).by(0)
    end
  end
end

require "rails_helper"
require "sidekiq/testing"
Sidekiq::Testing.fake!

describe SimpleScheduler::SchedulerJob, type: :job do
  # Active Job for testing
  class SimpleSchedulerTestJob < ActiveJob::Base
    def perform(time); end
  end

  # Sidekiq Worker for testing
  class SimpleSchedulerTestWorker
    include Sidekiq::Worker
    def perform(time); end
  end

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
      expect do
        described_class.perform_now
      end.to change(enqueued_jobs, :size).by(4)
    end
  end

  describe "scheduling an hourly task" do
    it "queues jobs for at least six hours into the future by default" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/hourly_task.yml")
      end.to change(enqueued_jobs, :size).by(7)
    end

    it "respects the queue_ahead global option" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/queue_ahead_global.yml")
      end.to change(enqueued_jobs, :size).by(3)
    end

    it "respects the queue_ahead option per task" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/queue_ahead_per_task.yml")
      end.to change(enqueued_jobs, :size).by(4)
    end
  end

  describe "scheduling a weekly task" do
    it "always queues two future jobs" do
      expect do
        described_class.perform_now("spec/simple_scheduler/config/active_job.yml")
      end.to change(enqueued_jobs, :size).by(2)
    end
  end
end

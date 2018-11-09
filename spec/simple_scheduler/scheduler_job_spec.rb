require "rails_helper"

describe SimpleScheduler::SchedulerJob, type: :job do
  let(:now) { Time.parse("2017-01-27 00:00:00 CST") }

  # Set the environment variable for a custom YAML configuration file.
  # @param path [String]
  def config_path(path)
    stub_const("ENV", ENV.to_hash.merge("SIMPLE_SCHEDULER_CONFIG" => path))
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
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(6)
      end
    end
  end

  describe "Sidekiq queue name" do
    it "uses 'default' as the queue name if `queue_name` isn't set in the config" do
      travel_to(now) do
        described_class.perform_now
        expect(enqueued_jobs.first[:queue]).to eq("default")
      end
    end

    it "uses the custom queue name from the config file when adding FutureJob" do
      config_path("spec/simple_scheduler/config/custom_queue_name.yml")
      travel_to(now) do
        described_class.perform_now
        expect(enqueued_jobs.first[:queue]).to eq("custom")
      end
    end
  end

  describe "loading a YML file with ERB tags" do
    it "parses the file and queues the jobs" do
      config_path("spec/simple_scheduler/config/erb_test.yml")
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(2)
      end
    end
  end

  describe 'scheduling a job with arguments' do
    it 'queues the required jobs' do
      config_path("spec/simple_scheduler/config/with_arguments.yml")
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(2)
      end
    end

    it 'queues the job with the arguments' do
      config_path("spec/simple_scheduler/config/with_arguments.yml")
      travel_to(now) do
        described_class.perform_now
      end

      expect(enqueued_jobs.first[:args].first).to include('arguments' => ['one'])
      puts enqueued_jobs
    end
  end

  describe "scheduling an hourly task" do
    it "queues jobs for at least six hours into the future by default" do
      config_path("spec/simple_scheduler/config/hourly_task.yml")
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(7)
      end
    end

    it "respects the queue_ahead global option" do
      config_path("spec/simple_scheduler/config/queue_ahead_global.yml")
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(3)
      end
    end

    it "respects the queue_ahead option per task" do
      config_path("spec/simple_scheduler/config/queue_ahead_per_task.yml")
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(4)
      end
    end
  end

  describe "scheduling a weekly task" do
    it "always queues two future jobs" do
      config_path("spec/simple_scheduler/config/active_job.yml")
      travel_to(now) do
        expect do
          described_class.perform_now
        end.to change(enqueued_jobs, :size).by(2)
      end
    end
  end
end

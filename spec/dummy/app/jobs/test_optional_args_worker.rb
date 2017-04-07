# Sidekiq Worker for testing a worker with optional args
class TestOptionalArgsWorker
  include Sidekiq::Worker
  def perform(scheduled_time, options = nil); end
end

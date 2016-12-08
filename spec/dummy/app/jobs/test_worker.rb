# Sidekiq Worker for testing
class TestWorker
  include Sidekiq::Worker
  def perform(scheduled_time); end
end

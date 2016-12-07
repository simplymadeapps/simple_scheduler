# Sidekiq Worker for testing
class SimpleSchedulerTestWorker
  include Sidekiq::Worker
  def perform(time); end
end

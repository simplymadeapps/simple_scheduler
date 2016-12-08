# Sidekiq Worker for testing a worker with no args
class TestNoArgsWorker
  include Sidekiq::Worker
  def perform; end
end

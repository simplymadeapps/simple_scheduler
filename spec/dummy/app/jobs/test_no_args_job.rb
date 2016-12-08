# Active Job for testing a job with no args
class TestNoArgsJob < ApplicationJob
  def perform; end
end

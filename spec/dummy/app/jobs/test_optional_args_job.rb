# Active Job for testing a job with optional args
class TestOptionalArgsJob < ApplicationJob
  def perform(scheduled_time, options = nil); end
end

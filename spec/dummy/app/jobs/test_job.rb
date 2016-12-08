# Active Job for testing
class TestJob < ApplicationJob
  def perform(scheduled_time); end
end

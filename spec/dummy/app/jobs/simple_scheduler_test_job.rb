# Active Job for testing
class SimpleSchedulerTestJob < ActiveJob::Base
  def perform(time); end
end

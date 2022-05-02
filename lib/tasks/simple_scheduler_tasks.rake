# frozen_string_literal: true

desc "Queue future jobs defined using Simple Scheduler"
task simple_scheduler: :environment do
  SimpleScheduler::SchedulerJob.perform_now
end

namespace :simple_scheduler do
  desc "Delete existing scheduled jobs and queue them from scratch"
  task reset: :environment do
    SimpleScheduler::FutureJob.delete_all
    SimpleScheduler::SchedulerJob.perform_now
  end
end

desc "Queue future jobs defined using Simple Scheduler"
task :simple_scheduler, [:config_path] => [:environment] do |_, args|
  SimpleScheduler::SchedulerJob.perform_now(args[:config_path])
end

namespace :simple_scheduler do
  desc "Delete existing scheduled jobs and queue them from scratch"
  task :reset, [:config_path] => [:environment] do |_, args|
    SimpleScheduler::FutureJob.delete_all
    SimpleScheduler::SchedulerJob.perform_now(args[:config_path])
  end
end

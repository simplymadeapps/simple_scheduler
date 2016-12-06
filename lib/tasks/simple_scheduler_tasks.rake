desc "Queue future jobs defined using Simple Scheduler"
task :simple_scheduler do
  SimpleScheduler::SchedulerJob.perform_later
end

desc "Queue future jobs defined using Simple Scheduler"
task :simple_scheduler, [:config_path] => [:environment] do |_, args|
  SimpleScheduler::SchedulerJob.perform_now(args[:config_path])
end

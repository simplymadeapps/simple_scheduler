module SimpleScheduler
  # Load the rake task into the Rails app
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.join(File.dirname(__FILE__), "tasks/simple_scheduler_tasks.rake")
    end
  end
end

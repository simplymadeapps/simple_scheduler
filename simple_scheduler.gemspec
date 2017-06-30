$LOAD_PATH.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "simple_scheduler/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "simple_scheduler"
  s.version     = SimpleScheduler::VERSION
  s.authors     = ["Brian Pattison"]
  s.email       = ["brian@brianpattison.com"]
  s.homepage    = "https://github.com/simplymadeapps/simple_scheduler"
  s.summary     = "An enhancement for Heroku Scheduler + Sidekiq for scheduling jobs at specific times."
  s.description = <<-DESCRIPTION
                  Simple Scheduler adds the ability to enhance Heroku Scheduler by using Sidekiq to queue
                  jobs in the future. This allows for defining specific run times (Ex: Every Sunday at 4 AM)
                  and running tasks more often than Heroku Scheduler's 10 minute limit.
                  DESCRIPTION
  s.license     = "MIT"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 4.2", "< 5.1.2"
  s.add_dependency "sidekiq", ">= 4.2"
  s.add_development_dependency "appraisal"
  s.add_development_dependency "codeclimate-test-reporter"
  s.add_development_dependency "rainbow", "~> 2.1.0"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "simplecov"
  s.add_development_dependency "simplecov-rcov"
end

$LOAD_PATH.push File.expand_path("lib", __dir__)

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
  s.license = "MIT"

  s.files = Dir["{lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]

  s.add_dependency "rails", ">= 5.0"
  s.add_dependency "sidekiq", ">= 5.0"
  s.add_development_dependency "appraisal"
  s.add_development_dependency "rainbow"
  s.add_development_dependency "rspec-rails"
  s.add_development_dependency "rubocop", "~> 0.66.0"
  s.add_development_dependency "simplecov", "< 0.18" # https://github.com/codeclimate/test-reporter/issues/413
  s.add_development_dependency "simplecov-rcov"
end

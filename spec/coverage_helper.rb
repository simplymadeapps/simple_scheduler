require "simplecov"
require "simplecov-rcov"

# return non-zero if not met
SimpleCov.at_exit do
  SimpleCov.minimum_coverage 100
  SimpleCov.result.format!
end

SimpleCov.start do
  add_filter "lib/simple_scheduler/railtie"
  add_filter "/spec/"
end

# Format the reports in a way I like
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter

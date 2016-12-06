require "simplecov"
require "simplecov-rcov"

# return non-zero if not met
SimpleCov.at_exit do
  SimpleCov.minimum_coverage 100
  SimpleCov.result.format!
end

SimpleCov.start do
  add_filter "/spec/"
  add_filter "config"
  add_filter "vendor"
end

# Format the reports in a way I like
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter

require 'puppetlabs_spec_helper/module_spec_helper'

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end

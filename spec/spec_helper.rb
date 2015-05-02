require 'rubygems'
require 'factory_girl'

# helper to load all of the classes for rspec tests
Dir.glob(File.dirname(__FILE__) + "/../lib/**/*.rb" ).each do |f|
  require_relative f
end

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|

  config.expect_with :rspec do |c|
    c.syntax = [:expect, :should] # add :should if we have to
  end
  
  config.include FactoryGirl::Syntax::Methods

end

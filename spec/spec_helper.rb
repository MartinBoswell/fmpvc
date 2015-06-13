$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'fmpvc'

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|

  config.expect_with :rspec do |c|
    c.syntax = [:expect, :should] # add :should if we have to
  end
  
end

# Facilitate file matching w/out regard for id and extension (which can easily change)
def find_path_with_base(f)
  Dir.glob(f + "*").first || "" # don't return nil; makes for bad spec error messages
end

# for delimiting spec runs in a shell
3.times do puts "###################################################################" end

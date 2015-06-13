require "fmpvc/version"
require "fmpvc/ddr"
require "fmpvc/fmpreport"
require "fmpvc/configuration"

module FMPVC
  
  class << self
    attr_accessor :configuration
  end
  def self.configure
    @configuration = Configuration.new
    yield(configuration)
  end
  
end

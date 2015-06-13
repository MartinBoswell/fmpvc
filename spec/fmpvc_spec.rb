require 'spec_helper'


describe FMPVC do
  
  it "has a version number" do
    expect(FMPVC::VERSION).not_to be nil
  end

  it "has a configuration" do
    expect(FMPVC.configuration.nil?).to be false
  end
  
end

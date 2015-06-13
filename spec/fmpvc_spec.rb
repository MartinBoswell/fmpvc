require 'spec_helper'


describe FMPVC do
  
  before do
    FMPVC.configure do |config|

    end
  end

  it 'has a version number' do
    expect(FMPVC::VERSION).not_to be nil
  end

  it 'has a configuration' do
    expect(FMPVC.configuration.nil?).to be false
  end
  
end

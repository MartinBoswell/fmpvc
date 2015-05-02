require_relative '../spec_helper'
include FMPVC

describe DDR do
  
  it "should be a DDR" do
    DDR.new.class.should == DDR
  end

  it "should read a Summary.xml from disk" do
    TEST_1_DEFAULT_FILE = IO.read("../data/test_1/Summary.xml")
    expect(DDR.new(TEST_1_DEFAULT_FILE).file).to be "xyz" # ...or something like that
  end

  it "should throw an error if type is not Summary" 
  it "should list the associated ddr files" 
  
end

require_relative '../spec_helper'
include FMPVC

describe 'FMPReport' do
  
  let (:ddr)         { double("ddr", :base_dir => :'./spec/data/test_1/fmp_ddr/') }
  let (:report_file) { 'Movies_fmp12.xml' }
  let (:report1)     { FMPReport.new(report_file, ddr) }
  
  it "should create an fmreport from a file" do
    expect(report1).to be_instance_of(FMPReport)
    expect { FMPReport.new('path.xyz', ddr) }.to raise_error(RuntimeError)
  end
  
  it "should read the file content" do
    expect(report1.content).to match(/FMPReport link="Summary.xml"/) # failure gives massive, ugly output
  end
  
  it "should throw an error if the type isn't Report" do
    expect(report1.type).to eq("Report")
    expect {FMPReport.new("Summary.xml", ddr)}.to raise_error(RuntimeError) # bad report type
  end
  
  

  describe '#write_dir' do
  
    it "should create a filename_fmp12 directory on disk" do
      report1.write_dir
      expect(File.readable?(report1.report_filepath)).to be true
    end
  
  end

  describe '#write_scripts' do
  
    it "should create a script file on disk"
  
  
  end

  describe '#write_tables' do
  
    it "should create a table file on disk"
  
  
  end

end

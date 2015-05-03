require_relative '../spec_helper'
include FMPVC

describe 'FMPReport' do
  
  # clear the fmp_text directory (to make tests accurate for current iteration)
  
    
  let (:ddr1)        { double("ddr", :base_dir => :'./spec/data/test_1/fmp_ddr/') }
  let (:report_file) { 'Movies_fmp12.xml' }
  let (:report1)     { FMPReport.new(report_file, ddr1) }
  
  let (:ddr2)        { double("ddr", :base_dir => :'./spec/data/test_2/fmp_ddr/') }
  let (:report2)     { FMPReport.new(report_file, ddr2) }
  
  it "should create an fmreport from a file" do
    expect(report1).to be_instance_of(FMPReport)
    expect { FMPReport.new('path.xyz', ddr1) }.to raise_error(RuntimeError)
  end
  
  it "should read the file content" do
    expect(report1.content).to match(/FMPReport link="Summary.xml"/) # failure gives massive, ugly output
  end
  
  it "should throw an error if the type isn't Report" do
    expect(report1.type).to eq("Report")
    expect {FMPReport.new("Summary.xml", ddr1)}.to raise_error(RuntimeError) # bad report type
  end
  
  

  describe '#write_dir' do  
    it "should create a filename_fmp12 directory on disk" do
      # report1.write_dir
      expect(File.readable?(report1.report_dirpath)).to be true
      expect(File.readable?(report2.report_dirpath)).to be true
    end  
  end

  describe '#write_scripts' do
    it "should create a script file on disk" do
      # report1.write_scripts
      expect(Dir.glob(report1.report_dirpath + "/Scripts/*.txt").count).to eq(1)
    end
    it "should create script folders" do
      # report2.write_scripts
      expect(File.directory?(report2.report_dirpath + "/Scripts/Actors")).to be true
    end
    it "should create nested script folders"
  end

  



  describe '#write_tables' do
  
    it "should create a table file on disk"
  
  
  end

end

require_relative '../spec_helper'
include FMPVC

describe 'DDR' do
  
  let (:summary_dir) { './spec/data/test_1/fmp_ddr' }
  let (:ddr1)        { DDR.new(summary_dir) }
  let (:movie_xml1)  { './spec/data/test_1/fmp_ddr/Movies_fmp12.xml'}
  
  it "should read a Summary.xml from disk" do
    expect(ddr1).to be_instance_of(DDR)
  end
  
  it "should be able to read a differently named Summary file" do
    expect(DDR.new(summary_dir, "NOT_Summary.xml")).to be_instance_of(DDR)
  end

  it "should throw an error if type is not Summary" do  # since user may point to the wrong file
    expect(ddr1.type).to eq("Summary")
    expect { DDR.new(movie_xml1) }.to raise_error(RuntimeError)
  end
    
  it "should have at least one file node" do
    expect(ddr1.fmp_files.size).to be >= 1
  end
  
  it "should read the file names of the nodes" do
    expect(ddr1.fmp_files.first).to eq("Movies.fmp12")
  end
  
  it "should be able to determine the base directory of the FMP file" do
    expect(ddr1.base_dir).to eq(File.expand_path("./spec/data/test_1/fmp_ddr"))
    # expect(ddr1.base_dir).to eq("/Users/boswell/Dropbox/Projects/2015/Q1_FMP_versioning/fmp_versioning/spec/data/test_1/fmp_ddr")
  end
  it "should return list of the xml files" do
    expect(ddr1.xml_files.first).to match('Movies_fmp12.xml')
  end
  it "should generate the FMPReports itself on request" do
    expect(ddr1.process_reports.first.class).to be FMPVC::FMPReport
  end
  
  it "should write a Summary file with generation details"
  it "should write files to disk on command"
  
  
end

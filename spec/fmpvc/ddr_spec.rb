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
    expect(ddr1.base_dir_ddr).to eq(File.expand_path("./spec/data/test_1/fmp_ddr"))
    # expect(ddr1.base_dir_ddr).to eq("/Users/boswell/Dropbox/Projects/2015/Q1_FMP_versioning/fmp_versioning/spec/data/test_1/fmp_ddr")
  end
  it "should return list of the xml files" do
    expect(ddr1.xml_files.first).to match('Movies_fmp12.xml')
  end
  it "should generate the FMPReports itself on request" do
    ddr1.process_reports
    expect(ddr1.reports.first[:report].class).to be FMPVC::FMPReport
  end
  it "should write know its generator version" do
    expect(ddr1.fmpa_version).to eq("14.0.1")
  end
  it "should write know its creation date" do
    expect(ddr1.creation_date).to eq("2015-4-23")
  end
  it "should write know its creation time" do
    expect(ddr1.creation_time).to eq("4:50:35 PM")
  end

  # test file content
  it "should write files to disk on command" do
    ddr1.write_summary
    expect(File.readable?("#{ddr1.base_dir_text_path}/Summary.txt")).to be true
  end
  it "should write a Summary file with generation details" do 
    # ddr1.write_summary (only needed once, above)
    expect(IO.read("#{ddr1.base_dir_text_path}/Summary.txt")).to match(%r{FileMaker\ Pro\ version: \s+ 14\.0\.1 \s+ Creation\ Date: \s+ 2015-4-23}mx)
  end  
  it "should write a Summary file with a list of the reports" do 
    # ddr1.write_summary (only needed once, above)
    expect(IO.read("#{ddr1.base_dir_text_path}/Summary.txt")).to match(%r{Report .* -+ .* Movies\.fmp12}mx)
  end
  it "should write a Summary file with details about the reports" do 
    # ddr1.write_summary (only needed once, above)
    expect(IO.read("#{ddr1.base_dir_text_path}/Summary.txt")).to match(%r{Movies.fmp12 \s+ 3 \s+ 3 \s+ 2 \s+ 2 \s+ 3}mx)
  end
  it "should generate Summary yaml" do
    # ddr1.write_summary (only needed once, above)
    expect(IO.read("#{ddr1.base_dir_text_path}/Summary.txt")).to match(%r{File: \s+ link:\ "\.//Movies_fmp12\.xml" \s+ name:\ Movies.fmp12}mx)
  end
end

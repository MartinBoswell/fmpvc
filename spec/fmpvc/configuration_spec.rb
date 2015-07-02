require 'spec_helper'


describe FMPVC do
  
  before do
    FMPVC.configure do |config|

    end
  end


  it "has a configuration" do
    expect(FMPVC.configuration.nil?).to be false
  end
  it "has a 'quiet' attribute that is off by default" do 
    expect(FMPVC.configuration.quiet).to be false
  end
  it "produces YAML output by default" do
    expect(FMPVC.configuration.yaml).to be true
  end
  it "uses the DDR filename, 'Summary.xml' by default" do
    expect(FMPVC.configuration.ddr_filename). to eq 'Summary.xml'
  end
  it "looks for DDR in 'fmp_ddr' directory by default" do
    expect(FMPVC.configuration.ddr_dirname). to eq 'fmp_ddr'
  end
  it "puts text file into 'fmp_text' directory by default" do
    expect(FMPVC.configuration.text_dirname). to eq 'fmp_text'
  end
  it "produces a tree file by default (if command is available)" do
    expect(FMPVC.configuration.tree_filename).to eq 'tree.txt'
  end
  it "doesn't supress record info by default" do
    expect(FMPVC.configuration.show_record_info).to be true
  end
  
end


  

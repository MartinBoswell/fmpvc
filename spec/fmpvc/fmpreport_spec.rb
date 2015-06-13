require_relative '../spec_helper'
include FMPVC

describe 'FMPReport' do
  
  # clear the fmp_text directory (to make tests accurate for current iteration)
  # test_data = [ './spec/data/test_1/fmp_text' , './spec/data/test_2/fmp_text']
  # test_data.each do |a_dir|
  #   FileUtils.rm_rf(a_dir, :verbose => true) if File.directory?(a_dir)
  # end
    
  
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
      expect(File.readable?(report1.report_dirpath)).to be true
      expect(File.readable?(report2.report_dirpath)).to be true
    end  
  end

  describe '#write_scripts' do
    it "should create a script file on disk" do
      expect(Dir.glob(report2.report_dirpath + "/Scripts/Actors (id 6)/*.txt").count).to eq(2)
    end
    it "should create script folders" do
      # report2.write_scripts
      expect(File.directory?(report2.report_dirpath + "/Scripts/Actors (id 6)")).to be true
    end
    it "should create nested script folders" do 
      expect(File.directory?(report2.report_dirpath + "/Scripts/Actors (id 6)/Actor Triggers (id 10)")).to be true
    end
    it "should create scripts with good content" do
      actor_listing_content = IO.read(find_path_with_base(report2.report_dirpath + "/Scripts/Actors (id 6)/Actor Listing (id 3)"))
      expect(actor_listing_content).to match(%r{Go to Layout \[ “Actors” \(Actors\) \]})
    end
    it "should remove carriage returns in the middle of the script steps" do   # e.g. in Sort Records, GTRR.  They're \r in xml, but \n when extracted.
      actor_show_roles_content = IO.read(find_path_with_base(report2.report_dirpath + "/Scripts/Actors (id 6)/Actor | show roles (id 9)"))
      sort_record_regex = %r{Sort Records \[ Keep records in sorted order; Specified Sort Order: Roles::name; ascending \]\[ Restore; No dialog \]} 
      expect(actor_show_roles_content).to match(sort_record_regex)
    end
    
    it "should create files and directories with id extensions" do
      expect(find_path_with_base(report2.report_dirpath + "/Scripts/Actors (id 6)/Actor Listing (id 3)")).to match(%r{3})
    end
        
    it "should properly create folders with identical FMP names in the same location" do 
      expect(Dir.glob(report2.report_dirpath + "/Scripts/-----*").count).to eq(2)
    end
    it "should properly create scripts with identical FMP names in the same location" do
      expect(Dir.glob(report2.report_dirpath + "/Scripts/----- (id 19)/pending - new Actor*").count).to eq(2)
    end
    it "should create scripts and folders that have slashes in their FMP names" do
      sanitzed_files = Dir.glob(report2.report_dirpath + "/Scripts/Filesystem Sanitation (id 25)/*.txt")
      expect(sanitzed_files[0]).to match(%r{Actor.Actress Information})
      expect(sanitzed_files[1]).to match(%r{Movie.Film Display})
    end
        

    it "should clean previous data, i.e. clean the fmp_text folders" do
      # create a file in the fmp_text dir
      temp_test_file = "#{ddr2.base_dir}/../fmp_text/#{report_file}/TEST_FILE_FOR_CLEANING.txt"
      File.open(temp_test_file, 'w') { |f| f.puts 'For dir clean test.\n'}
      # create a ddr
      new_report = FMPReport.new(report_file, ddr2)
      # file should have been cleaned
      expect(File.exists?(temp_test_file)).to be false
    end
  end

  
  describe '#write_value_lists' do
  
    it "should create a value list file on disk" do
      expect(Dir.glob(report2.report_dirpath + "/ValueLists/*.txt").count).to be >=3
    end
    it "should create value lists with good content" do
      value_list_content = IO.read(find_path_with_base(report2.report_dirpath + "/ValueLists/Favorite Roles"))
      expect(value_list_content).to match(%r{Randall McMurphy\nLone Watie\n- \n})
    end
    it "should handle non-custom value lists" do
      value_list_content = IO.read(find_path_with_base(report2.report_dirpath + "/ValueLists/Role Categories"))
      expect(value_list_content).to match(%r{Source: \s+ value: \s+ Field}mx)
    end
    
  end

  describe '#write_custom_functions' do
  
    it "should create a custom function file on disk" do
      expect(Dir.glob(report2.report_dirpath + "/CustomFunctions/*.txt").count).to be >=2
      # expect function_list to contain "ramones_name"
    end
    it "should create custom functions with good content" do
      custom_function_content = IO.read(find_path_with_base(report2.report_dirpath + "/CustomFunctions/ramones_name"))
      expect(custom_function_content).to match(%r{actor_first & " Ramone"})
    end
    it "should reproduce the original whitespace formatting" do
      custom_function_content = IO.read(find_path_with_base(report2.report_dirpath + "/CustomFunctions/alphabet_up_to_letter"))
      expect(custom_function_content).to match(%r{Code\(letter\) = 65 ; "A"})
    end
    
  end


  describe '#write_tables' do
    
    let( :movie_file )      { IO.read(find_path_with_base(report2.report_dirpath + "/Tables/Movies")) }
  
    it "should create a table file on disk" do
      table_list = Dir.glob(report2.report_dirpath + "/Tables/*.txt")
      expect(table_list.count).to be >=3
      # expect table_list to contain "Movies"
    end
    it "should create table files with good content" do
      table_file_content = IO.read(find_path_with_base(report2.report_dirpath + "/Tables/Roles"))
      expect(table_file_content).to match(%r{     5   _kF_movie_id                Number     Normal})
      
    end
    it "should create table files with field comments" do
      expect(movie_file).to match(%r{ \s+ 4 \s+ name \s+ Text \s+ Normal \s+ Name\ of\ the\ movie\.}mx)
    end
    it "should append the full YAML to the table's file" do
      expect(movie_file).to match(%r{--- \s+ BaseTable: \s+ id:}mx)
    end
    
  end
  
  describe '#element2yaml' do
    # Internal method;  no interface => no unit tests
    # it "should take a Nokogiri::XML::Element and return YAML"
  end

end

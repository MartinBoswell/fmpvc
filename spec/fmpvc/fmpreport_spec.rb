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
    
    let (:movie_file)         { IO.read(find_path_with_base(report2.report_dirpath + "/Tables/Movies")) }
  
    it "should create a table file on disk" do
      table_list = Dir.glob(report2.report_dirpath + "/Tables/*.txt")
      expect(table_list.count).to be >=3
      # expect table_list to contain "Movies"
    end
    it "should create table files with good content" do
      table_file_content = IO.read(find_path_with_base(report2.report_dirpath + "/Tables/Roles"))
      expect(table_file_content).to match(%r{ \s+ 5 \s+ _kF_movie_id \s+ Number \s+ Normal})
    end
    it "should create table files with field comments" do
      expect(movie_file).to match(%r{ \s+ 4 \s+ name \s+ Text \s+ Normal \s+ Name\ of\ the\ movie\.}mx)
    end
    it "should append the full YAML to the table's file" do
      expect(movie_file).to match(%r{--- \s+ BaseTable: \s+ id:}mx)
    end
    
  end
  
  describe '#write_accounts' do
    
    let (:accounts_file_content)      { IO.read(find_path_with_base(report2.report_dirpath + "/Accounts")) }
    
    it "should create an accounts file" do
      expect(accounts_file_content).to match(%r{Admin})
    end
    it "should have good content in accounts file" do
      expect(accounts_file_content).to match(%r{ \s+ 4 \s+ Chapman \s+ Active \s+ FileMaker \s+ \[Data \s+ Entry \s+ Only\] \s+ False \s+ False \s+ Graham \s+ Chapman}mx) # table
      expect(accounts_file_content).to match(%r{id:\ '2' \s+ privilegeSet:\ "\[Full\ Access\]"}mx) # yaml
    end
  end
  
  describe '#write_privilege_sets' do

    let (:privileges_file_content)      { IO.read(find_path_with_base(report2.report_dirpath + "/PrivilegeSets")) }
    
    it "should create an privileges file" do
      expect(privileges_file_content).to match(%r{\[Full Access\]})
    end
    it "should have good content in privileges file" do
      expect(privileges_file_content).to match(%r{\[Full\ Access\] \s+ True \s+ True \s+ True \s+ True \s+ False \s+ True \s+ All \s+ CreateEditDelete \s+ Modifiable \s+ True \s+ Modifiable \s+ True \s+ Modifiable \s+ True \s+ access\ to\ everything}mx) # table
      expect(privileges_file_content).to match(%r{PrivilegeSet: \s+ comment: \s+ access\ to\ everything \s+ id: \s+ '\d+'}mx) # yaml
    end
  end
  
  describe '#write_extended_privileges' do

    let (:ext_privileges_file_content)      { IO.read(find_path_with_base(report2.report_dirpath + "/ExtendedPrivileges")) }
    
    it "should create an privileges file" do
      expect(ext_privileges_file_content).to match(%r{fmxml})
    end
    it "should have good content in privileges file" do
      expect(ext_privileges_file_content).to match(%r{\d \s+ fmxml \s+ Access\ via\ XML\ Web\ Publishing\ -\ FMS\ only}mx) # table
      expect(ext_privileges_file_content).to match(%r{comment: \s+ Access\ via\ XML\ Web\ Publishing\ -\ FMS\ only \s+ name: \s+ fmxml}mx) # yaml
    end
  end
  
  describe '#write_relationships' do
    
    let (:relationships_file_content)       { IO.read(find_path_with_base(report2.report_dirpath + "/Relationships"))}
    
    it "should create a relationships file" do
      expect(relationships_file_content).to match (%r{---\n})
    end
    it "should display the YAML" do
      expect(relationships_file_content).to match(%r{table:\ Roles \s+ id:\ '5' \s+ name:\ _kF_movie_id}mx)
    end
    it "should list tables and TOs used by file" do
      expect(relationships_file_content).to match(%r{Roles\ \(131\) \s+ Roles\ \(1065091\)}mx)
    end
    it "should list relationships between TOs" do 
      expect(relationships_file_content).to match(%r{Roles::_kF_movie_id \s+ Equal \s+ Movies::_id}mx)
    end
        
  end
  
  describe '#write_menu_sets', :focus => false do
    
    let (:menuset_folder)                 { find_path_with_base(report2.report_dirpath + "/CustomMenuSets") }
    let (:menuset_file)                   { find_path_with_base(menuset_folder + '/Restricted Menus') }
    let (:menuset_file_content)           { IO.read(menuset_file) }
    
    it "should create a folder for menu sets" do
      expect(File.directory?(menuset_folder)).to be true
    end
    it "should create a file for each menu set" do
      expect(File.exists?(menuset_file)).to be true
    end
    it "should create a menu set that lists the menus" do
      expect(menuset_file_content).to match(%r{26 \s+ FileMaker\ Pro\ Copy \s+ 25 \s+ File\ Restricted}mx)
      expect(menuset_file_content).to match(%r{CustomMenu: \s+ -\ id:\ '26' \s+ name:\ FileMaker\ Pro\ Copy}mx)
    end
    
  end

  describe '#write_menus', :focus => false do
    
    let (:menu_folder)                    { find_path_with_base(report2.report_dirpath + "/CustomMenus") }
    let (:menu_file)                      { find_path_with_base(menu_folder + '/View Copy') }
    let (:menu_file_content)              { IO.read(menu_file) }
    
    it "should create a folder for menus" do
      expect(File.directory?(menu_folder)).to be true
    end
    it "should create a file for each menu" do
      expect(File.exists?(menu_file)).to be true
    end
    it "should create a menu that lists the menu items" do
      expect(menu_file_content).to match(%r{Layout\ Mode \s+ Preview\ Mode \s+ View\ as\ Form}mx)
    end
    
  end
  
  describe '#write_file_access', :focus => false do
    
    let (:file_access_file)               { find_path_with_base(report2.report_dirpath + "/FileAccess") }
    let (:file_access_file_content)       { IO.read(file_access_file) }
    
    it "should should create a file access file" do
      expect(File.exists?(file_access_file)).to be true
    end
    it "should display the YAML" do
      expect(file_access_file_content).to match(%r{requireAuthorization:\ 'True' \s+ Inbound: \s+ InboundAuthorization: \s+ id:\ '2'}mx)
    end
    it "should list file access parameters" do 
      expect(file_access_file_content).to match(%r{2 \s+ 2015-5-11\ 5:49:52\ PM \s+ Admin \s+ Movies\ Clone}mx)
    end
    
  end
  
  describe '#write_external_data_sources', :focus => false do
    
    let (:data_source_file)               { find_path_with_base(report2.report_dirpath + "/ExternalDataSources") }
    let (:data_source_file_content)       { IO.read(data_source_file) }
    
    it "should create an external data source file" do
      expect(File.exists?(data_source_file)).to be true
    end
    it "should contain YAML" do
      expect(data_source_file_content).to match(%r{pathList:\ file:../../FMServer_Sample \s+ name:\ Local\ Server_Sample \s+ OdbcDataSource: \s+ link:\ Movies_fmp12.xml}mx)
    end

    it "should show data source list" do 
      expect(data_source_file_content).to match(%r{3 \s+ ODBC\ Testing \s+ ODBC_Testing \s+ Movies_fmp12.xml}mx)
    end
  
  end
  
  describe '#write_file_options', :focus => true do
    
    let (:file_options_file)               { find_path_with_base(report2.report_dirpath + "/Options") }
    let (:file_options_file_content)       { IO.read(file_options_file) }
    
    it "should create an external data source file" do
      expect(File.exists?(file_options_file)).to be true
    end
    it "should contain YAML" do
      expect(file_options_file_content).to match(%r{OnOpen: \s+ MinimumAllowedVersion: \s+ name:\ '12.0' \s+ id:\ '1208'}mx)
    end

    it "should show data source list" do 
      expect(file_options_file_content).to match(%r{Minimum\ Allowed\ Version: \s+ 12.0 \s+ Account: \s+ Admin}mx)
    end
    
    it "should have a note explaining the encryption option" do
      expect(file_options_file_content).to match(%r{no\ encryption}imx)
    end
    
  end
  

  describe '#element2yaml'
    # Internal method;  no interface => no unit tests
    # it "should take a Nokogiri::XML::Element and return YAML"

end

=begin

Running single spec:

, :focus => true
rspec --tag focus spec/fmpvc/fmpreport_spec.rb

=end

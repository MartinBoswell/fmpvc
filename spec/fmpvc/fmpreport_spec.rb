require_relative '../spec_helper'
include FMPVC

require 'rspec/mocks'

describe 'FMPReport' do
  
  # Suppress stdout for progress indicators
  before(:all) do
    @stdout = $stdout
    $stdout = File.open(File::NULL, 'w+')
  end
  after(:all) do
    $stdout = @stdout
  end
  
  let (:ddr1)        { double("ddr", :base_dir_ddr => :'./spec/data/test_1/fmp_ddr/') }
  let (:report_file) { 'Movies_fmp12.xml' }
  let (:report1)     { FMPReport.new(report_file, ddr1) }

  let (:ddr2)        { double("ddr", :base_dir_ddr => :'./spec/data/test_2/fmp_ddr/') }
  let (:report2)     { FMPReport.new(report_file, ddr2) }

  it "should create an fmreport from a file" do
    expect(report1).to be_instance_of(FMPReport)
    expect { FMPReport.new('path.xyz', ddr1) }.to raise_error(RuntimeError)
  end
  it "should read the file content" do
    # disabled due to encoding issues 2015-08-02.  gives "invalid byte sequence in UTF-8" after removing coersion from FMPReport IO.read
    # expect(report1.content).to match(/FMPReport link="Summary.xml"/) # failure gives massive, ugly output
  end
  it "should throw an error if the type isn't Report" do
    expect(report1.type).to eq("Report")
    expect {FMPReport.new("Summary.xml", ddr1)}.to raise_error(RuntimeError) # bad report type
  end


  # for optimization of these specs 
  # only writing files once reduced time from 20+ sec to 3 sec (so far)
  describe "creating a temporary scope for the DDR doubles" do
    
    before(:context) do
      RSpec::Mocks.with_temporary_scope do
        report_file = 'Movies_fmp12.xml'
        @ddr1 = double('ddr', :base_dir_ddr => :'./spec/data/test_1/fmp_ddr/') 
        @report1 = FMPReport.new(report_file, @ddr1) 
        @report1.write_all_objects

        @ddr2 = double('ddr', :base_dir_ddr => :'./spec/data/test_2/fmp_ddr/') 
        @report2 = FMPReport.new(report_file, @ddr2) 
        @report2.write_all_objects
      end
    end
    
  
    describe '#write_dir' do  
      it "should create a filename_fmp12 directory on disk" do
        expect(File.readable?(@report1.report_dirpath)).to be true
        expect(File.readable?(@report2.report_dirpath)).to be true
      end  
    end

    describe '#write_scripts', :focus => false do
      it "should create a script file on disk" do
        expect(Dir.glob(@report2.report_dirpath + "/Scripts/Actors (id 6)/*.txt").count).to eq(2)
      end
      it "should create script folders" do
        # @report2.write_scripts
        expect(File.directory?(@report2.report_dirpath + "/Scripts/Actors (id 6)")).to be true
      end
      it "should create nested script folders" do 
        expect(File.directory?(@report2.report_dirpath + "/Scripts/Actors (id 6)/Actor Triggers (id 10)")).to be true
      end
      it "should have YAML content" do
        actor_listing_content = IO.read(find_path_with_base(@report2.report_dirpath + "/Scripts/Actors (id 6)/Actor Listing (id 3)"))
        expect(actor_listing_content).to match(%r{\-\ enable:\ 'True' \s+ id:\ '89' \s+ name:\ Comment \s+ StepText:\ "#\ Display\ a\ list\ of\ actors" \s+ Text:\ "\ Display\ a\ list\ of\ actors"}mx)
      end
      it "should create scripts with good content" do
        actor_listing_content = IO.read(find_path_with_base(@report2.report_dirpath + "/Scripts/Actors (id 6)/Actor Listing (id 3)"))
        expect(actor_listing_content).to match(%r{Go to Layout \[ “Actors” \(Actors\) \]})
      end
      it "should remove carriage returns in the middle of the script steps" do   # e.g. in Sort Records, GTRR.  They're \r in xml, but \n when extracted.
        actor_show_roles_content = IO.read(find_path_with_base(@report2.report_dirpath + "/Scripts/Actors (id 6)/Actor | show roles (id 9)"))
        sort_record_regex = %r{Sort Records \[ Keep records in sorted order; Specified Sort Order: Roles::name; ascending \]\[ Restore; No dialog \]} 
        expect(actor_show_roles_content).to match(sort_record_regex)
      end
      it "should 'comment out' disabled steps" do
        script_with_disabled_step = IO.read(find_path_with_base(@report2.report_dirpath + "/Scripts/DDR & fmpvc (id 31)/fmpvc - Save to Disk (id 29)"))
        expect(script_with_disabled_step).to match(%r{enable:\ 'False' \s+ id:\ '31' \s+ name:\ Adjust\ Window}mx)
      end
      it "should create files and directories with id extensions" do
        expect(find_path_with_base(@report2.report_dirpath + "/Scripts/Actors (id 6)/Actor Listing (id 3)")).to match(%r{3})
      end      
      it "should properly create folders with identical FMP names in the same location" do 
        expect(Dir.glob(@report2.report_dirpath + "/Scripts/-----*").count).to eq(2)
      end
      it "should properly create scripts with identical FMP names in the same location" do
        expect(Dir.glob(@report2.report_dirpath + "/Scripts/----- (id 19)/pending - new Actor*").count).to eq(2)
      end
      it "should create scripts and folders that have slashes in their FMP names" do
        sanitzed_files = Dir.glob(@report2.report_dirpath + "/Scripts/Filesystem Sanitation (id 25)/*.txt")
        expect(sanitzed_files[0]).to match(%r{Actor.Actress Information})
        expect(sanitzed_files[1]).to match(%r{Movie.Film Display})
      end
        
    end

    describe '#write_value_lists', :focus => false do
      
      let (:custom_value_list)            { IO.read(find_path_with_base(@report2.report_dirpath + "/ValueLists/Favorite Roles")) }
      let (:field_based_value_list)       { IO.read(find_path_with_base(@report2.report_dirpath + "/ValueLists/Role Categories")) }
  
      it "should create a value list file on disk" do
        expect(Dir.glob(@report2.report_dirpath + "/ValueLists/*.txt").count).to be >=3
      end
      it "should create value lists with good content" do
        expect(custom_value_list).to match(%r{Randall McMurphy\nLone Watie\n- \n})
      end
      it "should handle non-custom value lists" do
        expect(field_based_value_list).to match(%r{Source: \s+ value: \s+ Field}mx)
      end
      it "should have YAML appended to all functions" do
        expect(custom_value_list).to match(%r{Terry\ Fields \s+ --- \s+ ValueList: \s+ id:\ '3'}mx)
      end
      it "should have real YAML" do
        expect(field_based_value_list).to match(%r{name:\ Role\ Categories \s+ Source: \s+ value:\ Field}mx)
      end
    
    end

    describe '#write_custom_functions', :focus => false do
      
      let (:custom_function_content)      { IO.read(find_path_with_base(@report2.report_dirpath + "/CustomFunctions/ramones_name")) }
  
      it "should create a custom function file on disk" do
        expect(Dir.glob(@report2.report_dirpath + "/CustomFunctions/*.txt").count).to be >=2
        # expect function_list to contain "ramones_name"
      end
      it "should create custom functions with good content" do
        # custom_function_content = IO.read(find_path_with_base(@report2.report_dirpath + "/CustomFunctions/ramones_name"))
        expect(custom_function_content).to match(%r{actor_first & " Ramone"})
      end
      it "should reproduce the original whitespace formatting" do
        custom_function_content = IO.read(find_path_with_base(@report2.report_dirpath + "/CustomFunctions/alphabet_up_to_letter"))
        expect(custom_function_content).to match(%r{Code\(letter\) = 65 ; "A"})
      end
      it "should have YAML" do
        expect(custom_function_content).to match(%r{parameters:\ actor_first \s+ name:\ ramones_name}mx)
      end
      it "should have real YAML content" do 
        expect(custom_function_content).to match(%r{--- \s+ CustomFunction: \s+ id:\ '1' \s+ functionArity:\ '1'}mx)
      end
    
    end

    describe '#write_tables' do
    
      let (:movie_file)         { IO.read(find_path_with_base(@report2.report_dirpath + "/Tables/Movies")) }
  
      it "should create a table file on disk" do
        table_list = Dir.glob(@report2.report_dirpath + "/Tables/*.txt")
        expect(table_list.count).to be >=3
        # expect table_list to contain "Movies"
      end
      it "should create table files with good content" do
        table_file_content = IO.read(find_path_with_base(@report2.report_dirpath + "/Tables/Roles"))
        expect(table_file_content).to match(%r{ \s+ 5 \s+ _kF_movie_id \s+ Number \s+ Normal})
      end
      it "should create table files with field comments" do
        expect(movie_file).to match(%r{ \s+ 4 \s+ name \s+ Text \s+ Normal \s+ Name\ of\ the\ movie\.}mx)
      end
      it "should append the full YAML to the table's file" do
        expect(movie_file).to match(%r{--- \s+ BaseTable: \s+ id:}mx)
      end
    
    end
  
    describe '#write_accounts', :focus => false do
    
      let (:accounts_file_content)      { IO.read(find_path_with_base(@report2.report_dirpath + "/Accounts")) }
    
      it "should create an accounts file" do
        expect(accounts_file_content).to match(%r{Admin})
      end
      it "should have good content in accounts file" do
        expect(accounts_file_content).to match(%r{ \s+ 4 \s+ Chapman \s+ Active \s+ FileMaker \s+ \[Data \s+ Entry \s+ Only\] \s+ False \s+ False \s+ Graham \s+ Chapman}mx) # table
        expect(accounts_file_content).to match(%r{id:\ '2' \s+ privilegeSet:\ "\[Full\ Access\]"}mx) # yaml
      end
      it "should have good content in accounts file" do
        expect(accounts_file_content).to match(%r{AccountCatalog: \s+ Account: \s+ -\ id:\ '1' \s+ privilegeSet:}mx) 
      end

    end
  
    describe '#write_privilege_sets', :focus => false do

      let (:privileges_file_content)      { IO.read(find_path_with_base(@report2.report_dirpath + "/PrivilegeSets")) }
    
      it "should create an privileges file" do
        expect(privileges_file_content).to match(%r{\[Full Access\]})
      end
      it "should have good content in privileges file" do
        expect(privileges_file_content).to match(%r{\[Full\ Access\] \s+ True \s+ True \s+ True \s+ True \s+ False \s+ True \s+ All \s+ CreateEditDelete \s+ Modifiable \s+ True \s+ Modifiable \s+ True \s+ Modifiable \s+ True \s+ access\ to\ everything}mx) # table
        expect(privileges_file_content).to match(%r{PrivilegeSet: \s+ -\ comment: \s+ access\ to\ everything \s+ id: \s+ '\d+'}mx) # yaml
      end
      it "should have real YAML" do
        expect(privileges_file_content).to match(%r{--- \s+ PrivilegesCatalog: \s+ PrivilegeSet: \s+ -\ comment:\ access\ to\ everything \s+ id:\ '1'}mx)
      end
    end
  
    describe '#write_extended_privileges', :focus => false do

      let (:ext_privileges_file_content)      { IO.read(find_path_with_base(@report2.report_dirpath + "/ExtendedPrivileges")) }
    
      it "should create an privileges file" do
        expect(ext_privileges_file_content).to match(%r{fmxml})
      end
      it "should have good content in privileges file" do
        expect(ext_privileges_file_content).to match(%r{\d \s+ fmxml \s+ Access\ via\ XML\ Web\ Publishing\ -\ FMS\ only}mx) # table
        expect(ext_privileges_file_content).to match(%r{comment: \s+ Access\ via\ XML\ Web\ Publishing\ -\ FMS\ only \s+ name: \s+ fmxml}mx) # yaml
      end
      it "should have real YAML" do
        expect(ext_privileges_file_content).to match(%r{ExtendedPrivilegeCatalog: \s+ ExtendedPrivilege: \s+ -\ id:\ '1' \s+ comment:\ Access\ via}mx)
      end
    end
  
    describe '#write_relationships' do
    
      let (:relationships_file_content)       { IO.read(find_path_with_base(@report2.report_dirpath + "/Relationships"))}
    
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
      it "should display real YAML" do
        expect(relationships_file_content).to match(%r{--- \s+ RelationshipGraph: \s+ TableList: \s+ Table: \s+ -\ id:\ '1065090'}mx)
      end
      
        
    end
  
    describe '#write_menu_sets', :focus => false do
    
      let (:menuset_folder)                 { find_path_with_base(@report2.report_dirpath + "/CustomMenuSets") }
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
    
      let (:menu_folder)                    { find_path_with_base(@report2.report_dirpath + "/CustomMenus") }
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
      it "should handle a CustomMenu without a BaseMenu" do
        ddr5 = double('ddr', :base_dir_ddr => :'./spec/data/test_8/fmp_ddr/')
        expect{FMPReport.new('Untitled_fmp12.xml', ddr5)}.to_not raise_error
      end
    
    end
  
    describe '#write_file_access', :focus => false do
    
      let (:file_access_file)               { find_path_with_base(@report2.report_dirpath + "/FileAccess") }
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
    
      let (:data_source_file)               { find_path_with_base(@report2.report_dirpath + "/ExternalDataSources") }
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
  
    describe '#write_file_options', :focus => false do
    
      let (:file_options_file)               { find_path_with_base(@report2.report_dirpath + "/Options") }
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
      it "should handle reports generated by version 12"  do
        # version 12 doesn't have a /File/Options/Encryption node
        ddr3 = double('ddr', :base_dir_ddr => :'./spec/data/test_5/fmp_ddr/')
        expect{FMPReport.new('Untitled_v12_fmp12.xml', ddr3)}.to_not raise_error
      end
      it "should handle reports generated by version 11" do
      # no theme objects in the Layout nodes
        ddr4 = double('ddr', :base_dir_ddr => :'./spec/data/test_6/fmp_ddr/')
        expect{FMPReport.new('Untitled_fp7.xml', ddr4)}.to_not raise_error
      end
    
    end
  
    describe '#write_layouts', :focus => false do
    
      let (:layout_folder)                    { find_path_with_base(@report2.report_dirpath + "/Layouts") }
      let (:layout_file)                      { find_path_with_base(layout_folder + '/Actors') }
      let (:layout_file_content)              { IO.read(layout_file) }
      let (:nested_layout_folder)             { find_path_with_base(@report2.report_dirpath + "/Layouts/Script Resources") }
      let (:nested_layout_file)               { find_path_with_base(@report2.report_dirpath + "/Layouts/Script Resources (id 4)/DDR Instruction") }
    
      it "should create a folder for layouts" do
        expect(File.directory?(layout_folder)).to be true
      end
      it "should create a file for each layout" do
        expect(File.exists?(layout_file)).to be true
      end
      it "should create a layout file that lists the layout items" do
        expect(layout_file_content).to match(%r{Layout\ name: \s+ Actors \s+ id: \s+ 2}mx)
      end
      it "should create a layout file that lists the layout objects" do
        expect(layout_file_content).to match(%r{Field \s+ Actors::_s_creation \s+ Field \s+ Actors::_s_modification}mx)
      end
      it "should create nested layout folders" do 
        expect(File.directory?(nested_layout_folder)).to be true
      end
      it "should create script files in nested folders" do
        expect(File.exists?(nested_layout_file)).to be true
      end
      it "should create a layout file that lists hierarchical layout objects"
    
    end
  
    describe '#write_themes', :focus => false do
          
      let (:themes_file)               { find_path_with_base(@report2.report_dirpath + "/Themes") }
      let (:themes_file_content)       { IO.read(themes_file) }
  
      it "should create a themes file" do
        expect(File.exists?(themes_file)).to be true
      end
      it "should contain YAML" do
        expect(themes_file_content).to match(%r{internalName: \s+ com\.filemaker\.theme\.enlightened \s+ id: \s+ '01'}mx)
      end
      it "should list the included themes" do
        expect(themes_file_content).to match(%r{01 \s+ Enlightened \s+ Aspire \s+ 5 \s+ en \s+ com\.filemaker\.theme\.enlightened}mx)
      end
      it "should have real yaml" do
        expect(themes_file_content).to match(%r{--- \s+ ThemeCatalog: \s+ Theme: \s+ group:\ Aspire}mx)
      end
      it "should have good yaml for two or more themes"

    end
    
    describe '#post_notification', :focus => false do
      it "should update user on progress" do
        expect { @report2.post_notification('an object', 'Updating') }.to output("Updating an object\n").to_stdout
      end
      it "should update user on progress when reports are parsed" do
        expect { @report2.parse_fmp_obj( "/FMPReport/File/AccountCatalog", "/*[name()='Account']", Proc.new {"bogus\naccount\ncontent"}, true ) }.to output("  Parsing AccountCatalog\n").to_stdout
      end
      it "should update user on progress when reports are written to disk" do
        expect { @report2.write_obj_to_disk([], @report2.report_dirpath + "/Tables") }.to output("  Writing Movies_fmp12.xml/Tables\n").to_stdout
      end
    end
    
  end

  it "should clean previous data, i.e. clean the fmp_text folders" do
    report_file = 'Movies_fmp12.xml'
    @ddr3 = double('ddr', :base_dir_ddr => :'./spec/data/test_3/fmp_ddr/') 

    # create a file in the fmp_text dir
    temp_test_file = "#{@ddr3.base_dir_ddr}/../fmp_text/#{report_file}/TEST_FILE_FOR_CLEANING.txt"
    FileUtils.mkdir_p(@ddr3.base_dir_ddr.to_s + "../fmp_text/Movies_fmp12.xml")
    File.open(temp_test_file, 'w') { |f| f.puts 'For dir clean test.\n'}

    # create a ddr
    new_report = FMPReport.new(report_file, @ddr3)

    # now, the file should have been cleaned (i.e. removed)
    expect(File.exists?(temp_test_file)).to be false
  end

  describe '#write_all_objects' do
    let (:ddr4)         { double('ddr', :base_dir_ddr => :'./spec/data/test_4/fmp_ddr/') }
    let (:empty_report) { FMPReport.new("Untitled_fmp12.xml", ddr4) }

    it "should handle files without some of the fmpobjects" do
      empty_report.write_all_objects # basically, expect that this doesn't raise runtime error
      expect(File.directory?( find_path_with_base(empty_report.report_dirpath) )).to be true
    end
  end

  # causes other tests to fail when it's not at the end.  what am I manipulating?  can I double the config?
  describe '#suppress_record_info', :focus => false do
    before (:each) do
      FMPVC.configure do |config|
      end
    end
    it "should suppress record info when desired" do
      FMPVC.configuration.show_record_info = false
      ddr6 = double('ddr', :base_dir_ddr => :'./spec/data/test_7/fmp_ddr/')
      report7 = FMPReport.new('Untitled_fmp12.xml', ddr6)
      report7.write_all_objects
      report7_yaml = report7.tables[0][:yaml]
      expect(report7_yaml).to match(%r{records:\ ''}) # record count
      expect(report7_yaml).to match(%r{nextValue: 123abc}) # serial number 123abc1001
      expect(report7_yaml).to match(%r{nextValue: xyz}) # serial number 2001xyz
      expect(report7_yaml).to match(%r{nextValue: ''}) # serial number 2001xyz
    end
  end
  
  describe 'name quoting for xpath queries', :focus => false do
    before (:each) do
      FMPVC.configure do |config|
      end
    end
    it "should not throw an error with single-quotes in table names" do
      ddr9 = double('ddr', :base_dir_ddr => :'./spec/data/test_9/fmp_ddr/')
      expect {FMPReport.new("test_9-naming_fmp12.xml", ddr9)}.not_to raise_error() 
    end
    it "should show field names for table names that have single-quotes" do
      ddr9 = double('ddr', :base_dir_ddr => :'./spec/data/test_9/fmp_ddr/')
      report9 = FMPReport.new("test_9-naming_fmp12.xml", ddr9)
      report9.write_all_objects # for visual inspection
      # table 6: name '' with ' multiple ' single quotes
      expect(report9.tables[6][:name]).to match(%r{name '' with ' multiple ' single quotes})
      expect(report9.tables[6][:content]).to match(%r{field\ name\ with\ '\ pseudo-escaped\ \\'\ single\ \\\\'\ quote \s+ Text \s+ Normal}mx)
      # table 7: name with ' pseudo-escaped \' single \\' quote
      expect(report9.tables[7][:name]).to match(%r{name with ' pseudo-escaped \\' single \\\\' quote})
      expect(report9.tables[7][:content]).to match(%r{field\ name\ with\ '\ pseudo-escaped\ \\'\ single\ \\\\'\ quote \s+ Text \s+ Normal}mx)
    end
  end
  
  describe 'html escape characters', :focus => true do
    before (:each) do
      FMPVC.configure do |config|
      end
    end
    it "should see the greater-than symbols in scripts" do
      ddr10 = double('ddr', :base_dir_ddr => :'./spec/data/test_10/fmp_ddr/')
      report10 = FMPReport.new("test_10_html_escape_characters_fmp12.xml", ddr10)
      report10.write_all_objects # for visual inspection
      expect(report10.scripts[0][:name]).to match(%r{test for gt})
      expect(report10.scripts[0][:content]).to match(%r{If \[ 1 > 2 \]})
    end
  end
  
  
end

=begin

Running single spec (:focus => true):

rspec --tag focus spec/fmpvc/fmpreport_spec.rb

=end

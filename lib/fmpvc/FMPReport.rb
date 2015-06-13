module FMPVC
  
  require 'nokogiri'
  require 'fileutils'
	
  # for xml2yaml
  require 'active_support/core_ext/hash/conversions'
	require 'yaml'
  
  
  class FMPReport
    
    attr_reader :content, :type, :text_dir, :text_filename, :report_dirpath
    
    def initialize(report_filename, ddr)
      report_dirpath    = "#{ddr.base_dir}/#{report_filename}"  # location of the fmpfilename.xml file
      raise(RuntimeError, "Error: can't find the report file, #{report_dirpath}") unless File.readable?(report_dirpath)
      
      @content                      = IO.read(report_dirpath, mode: 'rb:UTF-16:UTF-8') # transcode is specifically for a spec content match
      @text_dir                     = "#{ddr.base_dir}../fmp_text"
      @text_filename                = fs_sanitize(report_filename)
      @report_dirpath               = "#{@text_dir}/#{@text_filename}"
      @tables_dirpath               = @report_dirpath + "/Tables"
      @scripts_dirpath              = @report_dirpath + "/Scripts"
      @value_lists_dirpath          = @report_dirpath + "/ValueLists"
      @custom_functions_dirpath     = @report_dirpath + "/CustomFunctions"
      @accounts_filepath            = @report_dirpath + "/Accounts.txt"
      
      self.parse
      self.clean_dir
      self.write_dir
      self.write_tables
      self.write_scripts
      self.write_value_lists
      self.write_custom_functions
      self.write_accounts
      
    end

    def parse
      @report = Nokogiri::XML(@content)
      @type = @report.xpath("//FMPReport").first["type"]
      
      # the report should be a "Report" type
      raise RuntimeError, "Incorrect file type: not an FMPReport Report file" unless @type == "Report"

    end

    def fs_sanitize(text_string)
      text_string.gsub(%r{[\/]}, '_') # just remove [ / ] for now.
    end
    
    def fs_id(fs_name, id)
      fs_name + " (id #{id})"
    end
    
    # e.g. /FMPReport/File/ScriptCatalog , /FMPReport/File/ScriptCatalog/Group[1]/Group
    # return: "/Actors/Actor Triggers"
    def disk_path_from_base(object_base, object_xpath, path = '')
      return "#{path}" if object_xpath == object_base
      curent_node_filename   = @report.xpath("#{object_xpath}").first['name']
      current_node_id        = @report.xpath("#{object_xpath}").first['id']
      parent_node_xpath      = @report.xpath("#{object_xpath}/..").first.path
      disk_path_from_base(object_base,  parent_node_xpath, "/#{fs_id(curent_node_filename, current_node_id)}" + "#{path}" )
    end
    
    def write_dir
      # raise(RuntimeError, "Error: there is no text output base dir (e.g. /fmp_text)") unless File.readable?(@text_dir)  # needed with _p?
      FileUtils.mkdir_p(@report_dirpath)
    end
    
    def clean_dir
      FileUtils.rm_rf(@report_dirpath)
    end
    
    def element2yaml(xml_element)
  		element_xml							= xml_element.to_xml({:encoding => 'UTF-8'}) # REMEMBER: the encoding
  		element_hash						= Hash.from_xml(element_xml)
  		element_yaml						= element_hash.to_yaml
    end
    
    ###
    ### create files
    ###
    
    def write_scripts(object_xpath = '/FMPReport/File/ScriptCatalog')
      current_disk_folder = disk_path_from_base('/FMPReport/File/ScriptCatalog', object_xpath)
      
      script_groups = @report.xpath("#{object_xpath}/*[name()='Group']")
      script_groups.each do |a_folder|
        script_dirname         = a_folder['name']
        script_dir_id          = a_folder['id']
        sanitized_dirname      = fs_sanitize(script_dirname)
        sanitized_dirname_id   = fs_id(sanitized_dirname, script_dir_id)
        full_folder_path = @scripts_dirpath + "#{current_disk_folder}/#{sanitized_dirname_id}"
        FileUtils.mkdir_p(full_folder_path)
        write_scripts(a_folder.path)
      end
      
      scripts = @report.xpath("#{object_xpath}/*[name()='Script']")
      scripts.each do |a_script|
        script_name    = a_script['name']
        script_id      = a_script['id']
        this_script_disk_path = @scripts_dirpath + "/#{current_disk_folder}"
        FileUtils.mkdir_p(this_script_disk_path) unless File.directory?(this_script_disk_path)
        
        # write the text value of the script line to the new script file
        sanitized_script_name        = fs_sanitize(script_name)
        sanitized_script_name_id     = fs_id(sanitized_script_name, script_id)
        sanitized_script_name_id_ext = sanitized_script_name_id + '.txt'
        File.open(this_script_disk_path + "/#{sanitized_script_name_id_ext}", 'w') do |f| 
          a_script.xpath("./StepList/Step/StepText").each {|t| f.puts t.text.gsub(%r{\n},'') } # remove \n from middle of steps
        end
      end
    end
    
    def write_value_lists(object_xpath = '/FMPReport/File/ValueListCatalog')
      FileUtils.mkdir_p(@value_lists_dirpath) unless File.directory?(@value_lists_dirpath)
      
      value_lists = @report.xpath("#{object_xpath}/*[name()='ValueList']")
      value_lists.each do |a_value_list|
        value_list_name                    = a_value_list['name']
        value_list_id                      = a_value_list['id']
        sanitized_value_list_name          = fs_sanitize(value_list_name)
        sanitized_value_list_name_id       = fs_id(sanitized_value_list_name, value_list_id)
        sanitized_value_list_name_id_ext   = sanitized_value_list_name_id + '.txt'
        File.open(@value_lists_dirpath + "/#{sanitized_value_list_name_id_ext}", 'w') do |f|
          source_type = a_value_list.xpath("./Source").first['value']
          if source_type == "Custom"
            a_value_list.xpath("./CustomValues/Text").each {|t| f.puts t.text}
          else # elsif source_type == "Field"
            f.write(element2yaml(a_value_list))
          end
        end
      end
      
    end
    
    def write_custom_functions(object_xpath = '/FMPReport/File/CustomFunctionCatalog')
      FileUtils.mkdir_p(@custom_functions_dirpath) unless File.directory?(@custom_functions_dirpath)
      
      custom_functions = @report.xpath("#{object_xpath}/*[name()='CustomFunction']")
      custom_functions.each do |a_custom_function|
        custom_function_name                  = a_custom_function['name']
        custom_function_id                    = a_custom_function['id']
        sanitized_custom_function_name        = fs_sanitize(custom_function_name)
        sanitized_custom_function_name_id     = fs_id(sanitized_custom_function_name, custom_function_id)
        sanitized_custom_function_name_id_ext = sanitized_custom_function_name_id + '.txt'
        File.open(@custom_functions_dirpath + "/#{sanitized_custom_function_name_id_ext}", 'w') do |f|
          a_custom_function.xpath("./Calculation").each {|t| f.print t.text}
        end
      end
      
    end
    
    def write_tables(object_xpath = '/FMPReport/File/BaseTableCatalog')
      FileUtils.mkdir_p(@tables_dirpath) unless File.directory?(@tables_dirpath)
      
      tables = @report.xpath("#{object_xpath}/*[name()='BaseTable']")
      tables.each do |a_table|
        table_name                  = a_table['name']
        table_id                    = a_table['id']
        sanitized_table_name        = fs_sanitize(table_name)
        sanitized_table_name_id     = fs_id(sanitized_table_name, table_id)
        sanitized_table_name_id_ext = sanitized_table_name_id + '.txt'
        table_format                = "%6d   %-25s   %-10s %-10s   %-50s"
        File.open(@tables_dirpath + "/#{sanitized_table_name_id_ext}", 'w') do |f|
          f.puts format(table_format, 0, "Field Name", "Data Type", "Field Type", "Comment")
          a_table.xpath("//BaseTable[@name='#{a_table['name']}']/FieldCatalog/*[name()='Field']").each do |t| 
            t_comment = t.xpath("./Comment").text
            f.puts format(table_format, t['id'], t['name'], t['dataType'], t['fieldType'], t_comment)
          end
          f.write(element2yaml(a_table)) # a_table.path) # 
        end
      end
    end

    def write_accounts
      account_path = '/FMPReport/File/AccountCatalog'
      accounts = @report.xpath("#{account_path}/*[name()='Account']")
      File.open(@accounts_filepath, 'w') do |f|
        yaml_output = "---\n"
        accounts_format        = "%6d  %-25s  %-10s  %-12s  %-20s  %-12s  %-12s  %-50s"
        accounts_header_format = accounts_format.gsub(%r{d}, 's')
        f.puts format(accounts_header_format, "id", "Name", "Status", "Management", "Privilege Set", "Empty Pass?", "Change Pass?", "Description")
        f.puts format(accounts_header_format, "--", "----", "------", "----------", "-------------", "-----------", "------------", "-----------")
        accounts.each do |an_account|
          account_name                                = an_account['name']
          account_id                                  = an_account['id']
          account_privilegeSet                        = an_account['privilegeSet']
          account_emptyPassword                       = an_account['emptyPassword']
          account_changePasswordOnNextLogin           = an_account['changePasswordOnNextLogin']
          account_managedBy                           = an_account['managedBy']
          account_status                              = an_account['status']
          account_Description                         = an_account.xpath('./Description').text
          f.puts format(    
                      accounts_format \
                    , account_id \
                    , account_name \
                    , account_status \
                    , account_managedBy \
                    , account_privilegeSet \
                    , account_emptyPassword \
                    , account_changePasswordOnNextLogin \
                    , account_Description
          )
          yaml_output += element2yaml(an_account).gsub(%r{\A --- \n}mx, '')
        end
        f.write(yaml_output)
      end
    end

  end

end


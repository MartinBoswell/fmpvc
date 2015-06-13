module FMPVC
  
  require 'nokogiri'
  require 'fileutils'
	
  # for xml2yaml
  require 'active_support/core_ext/hash/conversions'
	require 'yaml'

  NEWLINE = "\n"
  YAML_START = "---\n"
  
  class FMPReport
    
    attr_reader :content, :type, :text_dir, :text_filename, :report_dirpath
    
    def initialize(report_filename, ddr)
      report_dirpath    = "#{ddr.base_dir}/#{report_filename}"  # location of the fmpfilename.xml file
      raise(RuntimeError, "Error: can't find the report file, #{report_dirpath}") unless File.readable?(report_dirpath)
      
      @content                      = IO.read(report_dirpath, mode: 'rb:UTF-16:UTF-8') # transcode is specifically for a spec content match
      @text_dir                     = "#{ddr.base_dir}/../fmp_text"
      @text_filename                = fs_sanitize(report_filename)
      @report_dirpath               = "#{@text_dir}/#{@text_filename}"
      @tables_dirpath               = @report_dirpath + "/Tables"
      @scripts_dirpath              = @report_dirpath + "/Scripts"
      @value_lists_dirpath          = @report_dirpath + "/ValueLists"
      @custom_functions_dirpath     = @report_dirpath + "/CustomFunctions"
      @accounts_filepath            = @report_dirpath + "/Accounts.txt"
      @privileges_filepath          = @report_dirpath + "/PrivilegeSets.txt"
      @ext_privileges_filepath      = @report_dirpath + "/ExtendedPrivileges.txt"
      @relationships_filepath       = @report_dirpath + "/Relationships.txt"
      @menu_sets_dirpath            = @report_dirpath + "/CustomMenus"
      
      self.parse
      self.clean_dir
      self.write_dir
      self.write_tables
      self.write_scripts
      self.write_value_lists
      self.write_custom_functions
      self.write_accounts
      self.write_privilege_sets
      self.write_extended_privileges
      self.write_relationships
      self.write_menu_sets
      
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
            f.write(NEWLINE + element2yaml(a_value_list))
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
        table_name                                    = a_table['name']
        table_id                                      = a_table['id']
        sanitized_table_name                          = fs_sanitize(table_name)
        sanitized_table_name_id                       = fs_id(sanitized_table_name, table_id)
        sanitized_table_name_id_ext                   = sanitized_table_name_id + '.txt'
        table_format                                  = "%6d   %-25s   %-15s  %-15s   %-50s"
        table_header_format                           = table_format.gsub(%r{d}, 's')
        File.open(@tables_dirpath + "/#{sanitized_table_name_id_ext}", 'w') do |f|
          f.puts format(table_header_format, "id", "Field Name", "Data Type", "Field Type", "Comment")
          f.puts format(table_header_format, "--", "----------", "---------", "----------", "-------")
          a_table.xpath("//BaseTable[@name='#{a_table['name']}']/FieldCatalog/*[name()='Field']").each do |t| 
            t_comment = t.xpath("./Comment").text
            f.puts format(table_format, t['id'], t['name'], t['dataType'], t['fieldType'], t_comment)
          end
          f.write(NEWLINE + element2yaml(a_table)) # a_table.path) # 
        end
      end
    end

    def write_accounts
      account_path = '/FMPReport/File/AccountCatalog'
      accounts = @report.xpath("#{account_path}/*[name()='Account']")
      File.open(@accounts_filepath, 'w') do |f|
        yaml_output = YAML_START
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
        f.write(NEWLINE + yaml_output)
      end
    end

    def write_privilege_sets
      privilege_set_path = '/FMPReport/File/PrivilegesCatalog'
      privileges = @report.xpath("#{privilege_set_path}/*[name()='PrivilegeSet']")
      File.open(@privileges_filepath, 'w') do |f|
        yaml_output = YAML_START
        privileges_format        = "%6d  %-25s  %-8s  %-10s  %-15s  %-12s  %-12s  %-12s  %-8s  %-18s %-11s  %-10s   %-12s  %-10s   %-16s  %-10s  %-70s"
        privileges_header_format = privileges_format.gsub(%r{d}, 's')
        f.puts format(privileges_header_format, "id", "Name", "Print?", "Export?", "Manage Ext'd?", "Override?", "Disconnect?", "Password?", "Menus", "Records", "Layouts", "(Creation)", "ValueLists", "(Creation)", "Scripts", "(Creation)", "Description")
        f.puts format(privileges_header_format, "--", "----", "------", "-------", "-------------", "---------", "-----------", "---------", "-----", "-------", "-------", "----------", "----------", "----------", "-------", "----------", "-----------")
        privileges.each do |a_privilege_set|
          privilege_set_id                                    = a_privilege_set['id']
          privilege_set_name                                  = a_privilege_set['name']
          privilege_set_comment                               = a_privilege_set['comment']
          privilege_set_printing                              = a_privilege_set['printing']
          privilege_set_exporting                             = a_privilege_set['exporting']
          privilege_set_managedExtended                       = a_privilege_set['managedExtended']
          privilege_set_overrideValidationWarning             = a_privilege_set['overrideValidationWarning']
          privilege_set_idleDisconnect                        = a_privilege_set['idleDisconnect']
          privilege_set_allowModifyPassword                   = a_privilege_set['allowModifyPassword']
          privilege_set_menu                                  = a_privilege_set['menu']

          privilege_set_records_value                         = a_privilege_set.xpath('./Records').first['value']
          privilege_set_layouts_value                         = a_privilege_set.xpath('./Layouts').first['value']
          privilege_set_layouts_creation                      = a_privilege_set.xpath('./Layouts').first['allowCreation']
          privilege_set_valuelists_value                      = a_privilege_set.xpath('./ValueLists').first['value']
          privilege_set_valuelists_creation                   = a_privilege_set.xpath('./ValueLists').first['allowCreation']
          privilege_set_scripts_value                         = a_privilege_set.xpath('./Scripts').first['value']
          privilege_set_scripts_creation                      = a_privilege_set.xpath('./Scripts').first['allowCreation']
          
          f.puts format(
                      privileges_format \
                    , privilege_set_id \
                    , privilege_set_name \
                    , privilege_set_printing \
                    , privilege_set_exporting \
                    , privilege_set_managedExtended \
                    , privilege_set_overrideValidationWarning \
                    , privilege_set_idleDisconnect \
                    , privilege_set_allowModifyPassword \
                    , privilege_set_menu \
                    , privilege_set_records_value \
                    , privilege_set_layouts_value \
                    , privilege_set_layouts_creation \
                    , privilege_set_valuelists_value \
                    , privilege_set_valuelists_creation \
                    , privilege_set_scripts_value \
                    , privilege_set_scripts_creation \
                    , privilege_set_comment \
          )
          yaml_output += element2yaml(a_privilege_set).gsub(%r{\A --- \n}mx, '')
        end
        f.write(NEWLINE + yaml_output)
      end
    end

    def write_extended_privileges
      ext_privileges_path = '/FMPReport/File/ExtendedPrivilegeCatalog'
      ext_privileges = @report.xpath("#{ext_privileges_path}/*[name()='ExtendedPrivilege']")
      File.open(@ext_privileges_filepath, 'w') do |f|
        yaml_output = YAML_START
        ext_privilege_format        = "%6d  %-20s  %-85s  %-150s"
        ext_privilege_header_format = ext_privilege_format.gsub(%r{d}, 's')
        f.puts format(ext_privilege_header_format, "id", "Name", "Description", "Privilege Sets")
        f.puts format(ext_privilege_header_format, "--", "----", "-----------", "--------------")
        ext_privileges.each do |an_ext_privilege|
          ext_privilege_id                                    = an_ext_privilege['id']
          ext_privilege_name                                  = an_ext_privilege['name']
          ext_privilege_comment                               = an_ext_privilege['comment']
          ext_privilege_sets                                  = an_ext_privilege.xpath('./PrivilegeSetList/*[name()="PrivilegeSet"]').map {|s| s['name']}.join(", ")

          f.puts format(
                      ext_privilege_format \
                    , ext_privilege_id \
                    , ext_privilege_name \
                    , ext_privilege_comment \
                    , ext_privilege_sets \
          )
          yaml_output += element2yaml(an_ext_privilege).gsub(%r{\A --- \n}mx, '')
        end
        f.write(NEWLINE + yaml_output)
      end
    end
    
    def write_relationships
      relationships_path    = 'FMPReport/File/RelationshipGraph'
      tables                = @report.xpath("#{relationships_path}/TableList/*[name()='Table']")
      relationships         = @report.xpath("#{relationships_path}/RelationshipList/*[name()='Relationship']")
      File.open(@relationships_filepath, 'w') do |f|
        yaml_output = YAML_START
        table_format = "    %-25s  %-25s"
        f.puts "Tables\n"
        f.puts
        f.puts format(table_format, "Base Table (id)", "Table Occurance (id)")
        f.puts format(table_format, "---------------", "--------------------")
        f.puts
        tables.each do |a_table|
          table_id                                            = a_table['id']
          table_name                                          = a_table['name']
          basetable_id                                        = a_table['baseTableId']
          basetable_name                                      = a_table['baseTable']
          f.puts format(table_format, "#{basetable_name} (#{basetable_id})", "#{table_name} (#{table_id})")

          yaml_output += element2yaml(a_table).gsub(%r{\A --- \n}mx, '')
        end
        f.puts
        relationship_format = "        %-35s  %-15s  %-35s"
        f.puts "Relationships\n"
        relationships.each do |a_relationship|
          f.puts
          f.puts format("    Relationship: %-4d", a_relationship['id'])
          predicates = a_relationship.xpath('./JoinPredicateList/*[name()="JoinPredicate"]')
          predicates.each do |a_predicate|
            predicate_type                                    = a_predicate['type']

            left_field                                        = a_predicate.xpath('./LeftField/*[name()="Field"]').first
            left_table                                        = left_field['table']
            left_field_name                                   = left_field['name']

            right_field                                       = a_predicate.xpath('./RightField/*[name()="Field"]').first
            right_table                                       = right_field['table']
            right_field_name                                  = right_field['name']
            f.puts format(relationship_format, "#{left_table}::#{left_field_name}", "#{predicate_type}", "#{right_table}::#{right_field_name}")
          end
          
          yaml_output += element2yaml(a_relationship).gsub(%r{\A --- \n}mx, '')
        end
        f.write(NEWLINE + yaml_output)
      end

    end

    def write_menu_sets
      FileUtils.mkdir_p(@menu_sets_dirpath) unless File.directory?(@menu_sets_dirpath)
      
      menu_sets_path    = 'FMPReport/File/CustomMenuSetCatalog'
      menu_sets = @report.xpath("#{menu_sets_path}/*[name()='CustomMenuSet']")
      menu_sets.each do |a_menu_set|
        menu_set_name                                 = a_menu_set['name']
        menu_set_id                                   = a_menu_set['id']
        sanitized_menu_set_name                       = fs_sanitize(menu_set_name)
        sanitized_menu_set_name_id                    = fs_id(sanitized_menu_set_name, menu_set_id)
        sanitized_menu_set_name_id_ext                = sanitized_menu_set_name_id + '.txt'
        menu_set_format                               = "%6d  %-35s"
        menu_set_header_format                        = menu_set_format.gsub(%r{d}, 's')
        File.open(@menu_sets_dirpath + "/#{sanitized_menu_set_name_id_ext}", 'w') do |f|
          f.puts format(menu_set_header_format, "id", "Menu")
          f.puts format(menu_set_header_format, "--", "----")
          a_menu_set.xpath("./CustomMenuList/*[name()='CustomMenu']").each do |a_menu|
            f.puts format(menu_set_format, a_menu['id'], a_menu['name'])
          end
          f.write(NEWLINE + element2yaml(a_menu_set))
        end
      end
      
    end
      
      
      
      
      
      
      
      
      






  end

end


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
      
      self.define_content_procs
      
      
      # @tables_dirpath               = @report_dirpath + "/Tables"
      @scripts_dirpath              = @report_dirpath + "/Scripts"
      # @value_lists_dirpath          = @report_dirpath + "/ValueLists"
      @custom_functions_dirpath     = @report_dirpath + "/CustomFunctions"
      @accounts_filepath            = @report_dirpath + "/Accounts.txt"
      @privileges_filepath          = @report_dirpath + "/PrivilegeSets.txt"
      @ext_privileges_filepath      = @report_dirpath + "/ExtendedPrivileges.txt"
      @relationships_filepath       = @report_dirpath + "/Relationships.txt"
      @menu_sets_dirpath            = @report_dirpath + "/CustomMenuSets"
      @menus_dirpath                = @report_dirpath + "/CustomMenus"
      @file_access_filepath         = @report_dirpath + "/FileAccess.txt"
      @data_sources_filepath        = @report_dirpath + "/ExternalDataSources.txt"
      @file_options_filepath        = @report_dirpath + "/Options.txt"
      @layouts_dirpath              = @report_dirpath + "/Layouts"
      @themes_filepath              = @report_dirpath + "/Themes.txt"
      
      self.parse
      self.clean_dir
      self.write_dir
      self.write_scripts

      # self.parse_fms_obj("/FMPReport/File/ValueListCatalog/*[name()='ValueList']", @value_list_content) # write_value_lists
      @value_lists = parse_fms_obj("/FMPReport/File/ValueListCatalog/*[name()='ValueList']", @value_list_content)
      write_obj_to_disk(@value_lists, "/ValueLists")
      # self.write_tables
      @tables = parse_fms_obj("/FMPReport/File/BaseTableCatalog/*[name()='BaseTable']", @table_content)
      write_obj_to_disk(@tables, "/Tables")

      self.write_custom_functions
      self.write_accounts
      self.write_privilege_sets
      self.write_extended_privileges
      self.write_relationships
      self.write_menu_sets
      self.write_menus
      self.write_file_access
      self.write_external_data_sources
      self.write_file_options
      self.write_layouts
      self.write_themes
      
    end

    def parse
      @report = Nokogiri::XML(@content)
      @type = @report.xpath("//FMPReport").first["type"]
      
      # the report should be a "Report" type
      raise RuntimeError, "Incorrect file type: not an FMPReport Report file" unless @type == "Report"

    end

    def fs_sanitize(text_string)
      safe_name = text_string.gsub(%r{\A [\/\.]+ }mx, '') # remove leading dir symbols: . /
      safe_name.gsub(%r{[\/]}, '_') # just remove [ / ] for now.
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
    
    def define_content_procs
      
      @value_list_content = Proc.new do |a_value_list|
        content = ''
        source_type = a_value_list.xpath("./Source").first['value']
        if source_type == "Custom"
          a_value_list.xpath("./CustomValues/Text").each {|t| content += t.text}
        end  
        content
      end
      
      @table_content = Proc.new do |a_table|
        content = ''
        table_format            = "%6d   %-25s   %-15s  %-15s   %-50s"
        table_header_format     = table_format.gsub(%r{d}, 's')
        content                 += format(table_header_format, "id", "Field Name", "Data Type", "Field Type", "Comment")
        content                 += format(table_header_format, "--", "----------", "---------", "----------", "-------")
        a_table.xpath("//BaseTable[@name='#{a_table['name']}']/FieldCatalog/*[name()='Field']").each do |t| 
          t_comment             = t.xpath("./Comment").text
          content               += format(table_format, t['id'], t['name'], t['dataType'], t['fieldType'], t_comment)
        end
        content
      end
      
    end

    def parse_fms_obj(object_xpath, obj_content)
      objects_parsed = Array.new
      objects = @report.xpath(object_xpath)
      objects.each do |an_obj|
        obj_name                    = an_obj['name']
        obj_id                      = an_obj['id']
        sanitized_obj_name          = fs_sanitize(obj_name)
        sanitized_obj_name_id       = fs_id(sanitized_obj_name, obj_id)
        sanitized_obj_name_id_ext   = sanitized_obj_name_id + '.txt'
  
        content = obj_content.call(an_obj)
        yaml = element2yaml(an_obj)
  
        obj_parsed = {
            :name        => sanitized_obj_name_id_ext                        \
          , :type        => :file                                            \
          , :xpath       => an_obj.path                                      \
          , :content     => content                                          \
          , :yaml        => yaml                                             \
        }
        objects_parsed.push(obj_parsed)
      end
      objects_parsed
    end
    
    def write_obj_to_disk(objs, disk_location)
      full_path = @report_dirpath + disk_location
      if objs.class == Hash
        # single file objects
      elsif objs.class == Array
        # multi-file objects in directory
        FileUtils.mkdir_p(full_path) unless File.directory?(full_path)
        objs.each do |obj|
          File.open("#{full_path}/#{obj[:name]}", 'w') do |f|
            f.write(obj[:content] + NEWLINE) unless obj[:content] == ''
            f.write(NEWLINE + obj[:yaml])
          end
        end
      end
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
          f.write(NEWLINE + element2yaml(a_script))
        end
      end
    end
    
    # def write_value_lists(object_xpath = "/FMPReport/File/ValueListCatalog/*[name()='ValueList']", obj_content = value_list_content)
    #   parse_fms_obj(object_xpath, obj_content)
    # end

    # def write_value_lists(object_xpath = '/FMPReport/File/ValueListCatalog')
    #   FileUtils.mkdir_p(@value_lists_dirpath) unless File.directory?(@value_lists_dirpath)
    #
    #   value_lists = @report.xpath("#{object_xpath}/*[name()='ValueList']")
    #   value_lists.each do |a_value_list|
    #     value_list_name                    = a_value_list['name']
    #     value_list_id                      = a_value_list['id']
    #     sanitized_value_list_name          = fs_sanitize(value_list_name)
    #     sanitized_value_list_name_id       = fs_id(sanitized_value_list_name, value_list_id)
    #     sanitized_value_list_name_id_ext   = sanitized_value_list_name_id + '.txt'
    #     File.open(@value_lists_dirpath + "/#{sanitized_value_list_name_id_ext}", 'w') do |f|
    #       source_type = a_value_list.xpath("./Source").first['value']
    #       if source_type == "Custom"
    #         a_value_list.xpath("./CustomValues/Text").each {|t| f.puts t.text}
    #       end
    #       f.write(NEWLINE + element2yaml(a_value_list))
    #     end
    #   end
    #
    # end
    
    def write_custom_functions(object_xpath = '/FMPReport/File/CustomFunctionCatalog')
      FileUtils.mkdir_p(@custom_functions_dirpath) unless File.directory?(@custom_functions_dirpath)
      
      custom_functions                        = @report.xpath("#{object_xpath}/*[name()='CustomFunction']")
      custom_functions.each do |a_custom_function|
        custom_function_name                  = a_custom_function['name']
        custom_function_id                    = a_custom_function['id']
        sanitized_custom_function_name        = fs_sanitize(custom_function_name)
        sanitized_custom_function_name_id     = fs_id(sanitized_custom_function_name, custom_function_id)
        sanitized_custom_function_name_id_ext = sanitized_custom_function_name_id + '.txt'
        File.open(@custom_functions_dirpath + "/#{sanitized_custom_function_name_id_ext}", 'w') do |f|
          a_custom_function.xpath("./Calculation").each {|t| f.puts t.text}
          f.write(NEWLINE + element2yaml(a_custom_function))
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
      account_catalog = @report.xpath(account_path)
      accounts = @report.xpath("#{account_path}/*[name()='Account']")
      File.open(@accounts_filepath, 'w') do |f|
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
        end
        f.write(NEWLINE + element2yaml(account_catalog))
      end
    end

    def write_privilege_sets
      privilege_set_path          = '/FMPReport/File/PrivilegesCatalog'
      privilege_sets              = @report.xpath("#{privilege_set_path}")
      privileges                  = @report.xpath("#{privilege_set_path}/*[name()='PrivilegeSet']")
      File.open(@privileges_filepath, 'w') do |f|
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
        end
        f.write(NEWLINE + element2yaml(privilege_sets))
      end
    end

    def write_extended_privileges
      ext_privileges_path                 = '/FMPReport/File/ExtendedPrivilegeCatalog'
      ext_privilege_catalog               = @report.xpath(ext_privileges_path)
      ext_privileges                      = @report.xpath("#{ext_privileges_path}/*[name()='ExtendedPrivilege']")
      File.open(@ext_privileges_filepath, 'w') do |f|
        ext_privilege_format              = "%6d  %-20s  %-85s  %-150s"
        ext_privilege_header_format       = ext_privilege_format.gsub(%r{d}, 's')
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
        end
        f.write(NEWLINE + element2yaml(ext_privilege_catalog))
      end
    end
    
    def write_relationships
      relationships_path    = '/FMPReport/File/RelationshipGraph'
      relationship_graph    = @report.xpath("#{relationships_path}")
      tables                = @report.xpath("#{relationships_path}/TableList/*[name()='Table']")
      relationships         = @report.xpath("#{relationships_path}/RelationshipList/*[name()='Relationship']")
      File.open(@relationships_filepath, 'w') do |f|
        table_format = "    %-25s  %-25s"
        f.puts "Tables\n"
        f.puts
        f.puts format(table_format, "Base Table (id)", "Table occurrence (id)")
        f.puts format(table_format, "---------------", "---------------------")
        f.puts
        tables.each do |a_table|
          table_id                                            = a_table['id']
          table_name                                          = a_table['name']
          basetable_id                                        = a_table['baseTableId']
          basetable_name                                      = a_table['baseTable']
          f.puts format(table_format, "#{basetable_name} (#{basetable_id})", "#{table_name} (#{table_id})")
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
        end
        f.write(NEWLINE + element2yaml(relationship_graph))
      end

    end

    def write_menu_sets
      FileUtils.mkdir_p(@menu_sets_dirpath) unless File.directory?(@menu_sets_dirpath)
      
      menu_sets_path                                  = '/FMPReport/File/CustomMenuSetCatalog'
      menu_sets                                       = @report.xpath("#{menu_sets_path}/*[name()='CustomMenuSet']")
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
          
    def write_menus
      FileUtils.mkdir_p(@menus_dirpath) unless File.directory?(@menus_dirpath)
      
      menus_path = '/FMPReport/File/CustomMenuCatalog'
      menus = @report.xpath("#{menus_path}/*[name()='CustomMenu']")
      menus.each do |a_menu|
        menu_name                                 = a_menu['name']
        menu_id                                   = a_menu['id']
        sanitized_menu_name                       = fs_sanitize(menu_name)
        sanitized_menu_name_id                    = fs_id(sanitized_menu_name, menu_id)
        sanitized_menu_name_id_ext                = sanitized_menu_name_id + '.txt'
        File.open(@menus_dirpath + "/#{sanitized_menu_name_id_ext}", 'w') do |f|
          menu_comment = a_menu.xpath('./Comment').text
          menu_base = a_menu.xpath('./BaseMenu').first['name']
          f.puts "Name: #{menu_name}"
          f.puts "Base menu: #{menu_base}"
          f.puts "Comment: #{menu_comment}"
          f.puts
          menu_items = a_menu.xpath("./MenuItemList/*[name()='MenuItem']")
          menu_items.each do |an_item|
            an_item.xpath('./Command').each { |c| f.puts "#{c['name']}"}
          end
          f.write(NEWLINE + element2yaml(a_menu))
        end
      end
    end
      
    def write_file_access
      file_access_path                            = '/FMPReport/File/AuthFileCatalog'
      file_access                                 = @report.xpath("#{file_access_path}")
      inbound_access                              = file_access.xpath("./Inbound/*[name()='InboundAuthorization']")
      outbound_access                             = file_access.xpath("./Outbound/*[name()='OutboundAuthorization']")
      access_format                               = "          %6d  %-25s  %-25s  %-25s"
      access_format_header                        = access_format.gsub(%r{d}, 's')
      File.open(@file_access_filepath, 'w') do |f|
        auth_requirement = file_access.first['requireAuthorization']
        f.puts "Authorization required: #{auth_requirement}"
        if auth_requirement == "True"
          f.puts
          f.puts format(access_format_header, "id", "Timestamp", "Account", "Filenames")
          f.puts format(access_format_header, "--", "---------", "-------", "---------")
          f.puts format("%12s", "Inbound:")
          inbound_access.each do |i|
            f.puts format(access_format, i['id'], i['date'], i['user'], i['filenames'])
          end
          f.puts format("%12s", "Outbound:")
          outbound_access.each do |o|
            f.puts format(access_format, o['id'], o['date'], o['user'], o['filenames'])
          end
        end
        f.puts
        f.write(NEWLINE + element2yaml(file_access))
      end
      
    end
    
    def write_external_data_sources
      data_sources_path                         = '/FMPReport/File/ExternalDataSourcesCatalog'
      data_sources                              = @report.xpath(data_sources_path)
      file_references                           = data_sources.xpath("./*[name()='FileReference']")
      odbc_sources                              = data_sources.xpath("./*[name()='OdbcDataSource']")
      file_references_format                    = "   %6d  %-25s  %-25s"
      file_references_header_format             = file_references_format.gsub(%r{d},'s')
      odbc_source_format                        = "   %6d  %-25s  %-25s  %-25s"
      odbc_source_header_format                 = odbc_source_format.gsub(%r{d},'s')
      File.open(@data_sources_filepath, 'w') do |f|
        f.puts format(file_references_header_format, "id", "File Reference", "Path List")
        f.puts format(file_references_header_format, "--", "--------------", "---------")
        file_references.each do |r|
          f.puts format(file_references_format, r['id'], r['name'], r['pathList'])
        end
        f.puts
        f.puts format(odbc_source_header_format, "id", "ODBC Source", "DSN", "Link")
        f.puts format(odbc_source_header_format, "--", "-----------", "---", "----")
        odbc_sources.each do |s|
          f.puts format(odbc_source_format, s['id'], s['name'], s['DSN'], s['link'])
        end
        f.write(NEWLINE + element2yaml(data_sources))
      end
      
    end
    
    def write_file_options
      file_options_path                          = '/FMPReport/File/Options'
      file_options                               = @report.xpath(file_options_path)
      file_options_format                        = "    %-27s  %-30s"
      trigger_format                             = "        %-23s  %-30s"
      
      # optional <FMPReport><File><Options>, see DDR_grammar doc, p. 5
      open_account_search                        = file_options.xpath('./OnOpen/Account')
      open_account                               = (open_account_search.size > 0 ? open_account_search.first['name']: "")
      open_layout_search                         = file_options.xpath('./OnOpen/Layout')
      open_layout                                = ( open_layout_search.size > 0 ? open_layout_search.first['name'] : "" )
      
      encryption_type                            = file_options.xpath('./Encryption').first['type']
      encryption_note                            = case encryption_type
                                                   when "0"
                                                     "no encryption"
                                                   when "1"
                                                     "AES256 encrypted"
                                                   end
      
      File.open(@file_options_filepath, 'w') do |f|
        f.puts "File Options"
        f.puts "------------"
        f.puts
        f.puts format(file_options_format, "Encryption:", "#{encryption_type} (#{encryption_note})")
        f.puts ""
    		f.puts format(file_options_format, "Minimum Allowed Version:", file_options.xpath('./OnOpen/MinimumAllowedVersion').first['name'])
    		f.puts format(file_options_format, "Account:", open_account)
    		f.puts format(file_options_format, "Layout:", open_layout)
        f.puts ""
        f.puts format(file_options_format, "Default Custom Menu Set:", file_options.xpath('./DefaultCustomMenuSet/CustomMenuSet').first['name'])
        f.puts ""
        f.puts "    Triggers"
        file_options.xpath('./WindowTriggers/*').each do |t|
          f.puts format(trigger_format, t.name, t.xpath('./Script').first['name'])
        end
        f.write(NEWLINE + element2yaml(file_options))
      end
      
      
      
    end
    
    def write_layouts(layouts_path = '/FMPReport/File/LayoutCatalog')
      FileUtils.mkdir_p(@layouts_dirpath) unless File.directory?(@layouts_dirpath)
      current_disk_folder = disk_path_from_base('/FMPReport/File/LayoutCatalog', layouts_path)
      
      layout_groups = @report.xpath("#{layouts_path}/*[name()='Group']")
      layout_groups.each do |a_folder|
        layout_dirname         = a_folder['name']
        layout_dir_id          = a_folder['id']
        sanitized_dirname      = fs_sanitize(layout_dirname)
        sanitized_dirname_id   = fs_id(sanitized_dirname, layout_dir_id)
        full_folder_path = @layouts_dirpath + "#{current_disk_folder}/#{sanitized_dirname_id}"
        FileUtils.mkdir_p(full_folder_path)
        write_layouts(a_folder.path)
      end
      
      layouts = @report.xpath("#{layouts_path}/*[name()='Layout']")
      layouts.each do |l|
        layout_name                                 = l['name']
        layout_id                                   = l['id']
        sanitized_layout_name                       = fs_sanitize(layout_name)
        sanitized_layout_name_id                    = fs_id(sanitized_layout_name, layout_id)
        sanitized_layout_name_id_ext                = sanitized_layout_name_id + '.txt'
        this_layout_disk_path                       = @layouts_dirpath + "/#{current_disk_folder}"
        File.open("#{this_layout_disk_path}/#{sanitized_layout_name_id_ext}", 'w') do |f|
          layout_table                              = l.xpath('./Table').first['name']
          layout_theme                              = l.xpath('./Theme').first['name']
          layout_format = "%18s %-25s"
          object_format = "                    %-16s  %-35s"
          f.puts format(layout_format, "Layout name: ", layout_name)
          f.puts format(layout_format, "id: ",          layout_id)
          f.puts format(layout_format, "Table: ",       layout_table)
          f.puts format(layout_format, "Theme: ",       layout_theme)
          f.puts
          f.puts format(layout_format, "Objects: ", '')
          layout_objects = l.xpath("./*[name()='Object']")                          # find all objects
          layout_objects_types = layout_objects.map { |o| o['type']}                # list of 'types'
          if !layout_objects_types.empty?                                           # [].uniq! => nil - don't do that
            layout_objects_types.uniq! 
            f.puts format(object_format, "Type", "'Name'" )
            f.puts format(object_format, "----", "------" )
          end
          layout_objects_types.each do |a_type|
            selected_objects = layout_objects.select { |o| o['type'] == a_type }    # get all the objects of a given type
              selected_objects.each do |type_obj| # collect all objects of type
              f.puts format(object_format, type_obj['type'], type_obj.xpath('./*/Name').text) unless type_obj['type'] == "Text"
            end
          end
          f.write(NEWLINE + element2yaml(l))
        end
      end
    end
    
    def write_themes
      themes_path                                 = '/FMPReport/File/ThemeCatalog'
      themes_yaml                                 = element2yaml(@report.xpath(themes_path))
      themes                                      = @report.xpath(themes_path + "/*[name()='Theme']")
      File.open(@themes_filepath, 'w') do |f|
        theme_format = "  %6s  %-20s  %-20s  %6s  %-20s  %-20s"
        f.puts format(theme_format, "id", "Name", "Group", "Version", "Locale", "Internal Name")
        f.puts format(theme_format, "--", "----", "-----", "-------", "------", "-------------")
        themes.each do |a_theme|
          f.puts format(theme_format, a_theme['id'], a_theme['name'], a_theme['group'], a_theme['version'], a_theme['locale'], a_theme['internalName'])
        end
        f.write(NEWLINE + themes_yaml)
      end
    end
    
  end

end


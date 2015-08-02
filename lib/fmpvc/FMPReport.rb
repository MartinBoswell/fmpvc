module FMPVC
  
  require 'nokogiri'
  require 'fileutils'
	
  # for xml2yaml
  require 'active_support/core_ext/hash/conversions'
	require 'yaml'

  NEWLINE = "\n"
  
  class FMPReport
    
    attr_reader :content, :type, :text_dir, :text_filename, :report_dirpath, :named_objects, :tables
    
    def initialize(report_filename, ddr)
      report_dirpath    = "#{ddr.base_dir_ddr}/#{report_filename}"  # location of the fmpfilename.xml file
      raise(RuntimeError, "Error: can't find the report file, #{report_dirpath}") unless File.readable?(report_dirpath)
      
      @content             = IO.read(report_dirpath, mode: 'rb:UTF-16:UTF-8') # transcode is specifically for a spec content match
      @text_dir            = "#{ddr.base_dir_ddr}/../#{FMPVC.configuration.text_dirname}"
      @text_filename       = fs_sanitize(report_filename)
      @report_dirpath      = "#{@text_dir}/#{@text_filename}"
      
      self.define_content_procs
      
      self.parse
      self.clean_dir
      self.write_dir
      
      ### hierarchical folder structure
      @scripts                  = parse_fmp_obj( "/FMPReport/File/ScriptCatalog",               "/*[name()='Group' or name()='Script']",      @script_content               )
      @layouts                  = parse_fmp_obj( "/FMPReport/File/LayoutCatalog",               "/*[name()='Group' or name()='Layout']",      @layouts_content              )
      ### single folder with files                                                                                                                                          
      @value_lists              = parse_fmp_obj( "/FMPReport/File/ValueListCatalog",           "/*[name()='ValueList']",                      @value_list_content           )
      @tables                   = parse_fmp_obj( "/FMPReport/File/BaseTableCatalog",           "/*[name()='BaseTable']",                      @table_content                )
      suppress_record_info if FMPVC.configuration.show_record_info == false
      @custom_functions         = parse_fmp_obj( "/FMPReport/File/CustomFunctionCatalog",      "/*[name()='CustomFunction']",                 @custom_function_content      )
      @menu_sets                = parse_fmp_obj( "/FMPReport/File/CustomMenuSetCatalog",       "/*[name()='CustomMenuSet']",                  @menu_sets_content            )
      @custom_menus             = parse_fmp_obj( "/FMPReport/File/CustomMenuCatalog",          "/*[name()='CustomMenu']",                     @custom_menus_content         )
      ### single file output                                                                                                                  
      @accounts                 = parse_fmp_obj( "/FMPReport/File/AccountCatalog",              "/*[name()='Account']",                       @accounts_content,            true )
      @privileges               = parse_fmp_obj( "/FMPReport/File/PrivilegesCatalog",           "/*[name()='PrivilegeSet']",                  @privileges_content,          true )
      @extended_privileges      = parse_fmp_obj( "/FMPReport/File/ExtendedPrivilegeCatalog",    "/*[name()='ExtendedPrivilege']",             @extended_priviledge_content, true )
      @relationships            = parse_fmp_obj( "/FMPReport/File/RelationshipGraph",           "/RelationshipList/*[name()='Relationship']", @relationships_content,       true )
      @file_access              = parse_fmp_obj( "/FMPReport/File/AuthFileCatalog",             '',                                           @file_access_content,         true )       
      @external_sources         = parse_fmp_obj( "/FMPReport/File/ExternalDataSourcesCatalog",  '',                                           @external_sources_content,    true )
      @file_options             = parse_fmp_obj( "/FMPReport/File/Options",                     '',                                           @file_options_content,        true )       
      @themes                   = parse_fmp_obj( "/FMPReport/File/ThemeCatalog",                "/*[name()='Theme']",                         @themes_content,              true )

      @named_objects = [
        { :content =>  @scripts,             :disk_path => "/Scripts"                 }, 
        { :content =>  @layouts,             :disk_path => "/Layouts"                 }, 
        { :content =>  @value_lists,         :disk_path => "/ValueLists"              }, 
        { :content =>  @tables,              :disk_path => "/Tables"                  }, 
        { :content =>  @custom_functions,    :disk_path => "/CustomFunctions"         }, 
        { :content =>  @menu_sets,           :disk_path => "/CustomMenuSets"          }, 
        { :content =>  @custom_menus,        :disk_path => "/CustomMenus"             }, 
        { :content =>  @accounts,            :disk_path => "/Accounts.txt"            }, 
        { :content =>  @privileges,          :disk_path => "/PrivilegeSets.txt"       }, 
        { :content =>  @extended_privileges, :disk_path => "/ExtendedPrivileges.txt"  }, 
        { :content =>  @relationships,       :disk_path => "/Relationships.txt"       }, 
        { :content =>  @file_access,         :disk_path => "/FileAccess.txt"          }, 
        { :content =>  @external_sources,    :disk_path => "/ExternalDataSources.txt" }, 
        { :content =>  @file_options,        :disk_path => "/Options.txt"             }, 
        { :content =>  @themes,              :disk_path => "/Themes.txt"              }
      ]
      
    end
    
    def write_all_objects()
      post_notification('report files', 'Writing')
      @named_objects.each { |obj| write_obj_to_disk(obj[:content], @report_dirpath + obj[:disk_path])}
    end

    def parse
      @report = Nokogiri::XML(@content)
      @type = @report.xpath("//FMPReport").first["type"]
      raise RuntimeError, "Incorrect file type: not an FMPReport Report file" unless @type == "Report"
    end

    def fs_sanitize(text_string)
      safe_name = text_string.gsub(%r{\A [\/\.]+ }mx, '')      # remove leading dir symbols: . /
      safe_name.gsub(%r{[\/]}, '_')                            # just remove [ / ] for now.
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
      FileUtils.mkdir_p(@report_dirpath)
    end
    
    def clean_dir
      FileUtils.rm_rf(@report_dirpath)
    end
    
    def element2yaml(xml_element)
      return '' unless FMPVC.configuration.yaml
  		element_xml							= xml_element.to_xml({:encoding => 'UTF-8'}) # REMEMBER: the encoding
  		element_hash						= Hash.from_xml(element_xml)
  		element_yaml						= element_hash.to_yaml
    end
    
    def post_notification(object, verb = 'Updating')
      $stdout.puts [verb, object].join(" ") unless FMPVC.configuration.quiet
    end
    
    def suppress_record_info()
      @tables.each do |a_table|
        current_yaml = a_table[:yaml]
        yaml_serial_number_fixed = current_yaml.gsub(%r{(nextValue:.*\D)(\d+)(\D*?)(?=\n)}, '\1\3') # e.g. nextValue: 123serial456 or nextValue: 123serial
        yaml_record_count_fixed = yaml_serial_number_fixed.gsub(%r{(BaseTable: \s+ id:\ '\d+' \s+ records:\ '.*?)(\d+)'}mx, '\1\'') # e.g. records: '234'
        a_table[:yaml] = yaml_record_count_fixed
    end
    end
    

    def parse_fmp_obj(object_base, object_nodes, obj_content, one_file = false)
      post_notification(object_base.gsub(%r{\/FMPReport\/File\/},''), '  Parsing')
      objects_parsed = Array.new
      objects = @report.xpath("#{object_base}#{object_nodes}")
      objects.each do |an_obj|
        obj_id                      = an_obj['id']
        if one_file
          sanitized_obj_name_id_ext   = nil
        else
          obj_name                    = an_obj['name'] 
          sanitized_obj_name          = fs_sanitize(obj_name)
          sanitized_obj_name_id       = fs_id(sanitized_obj_name, obj_id)
          sanitized_obj_name_id_ext   = sanitized_obj_name_id + '.txt'
        end
        
        obj_parsed = {
            :name        => sanitized_obj_name_id_ext                        \
          , :type        => :file                                            \
          , :xpath       => an_obj.path                                      \
        }
        
        # if it's a Group, then make a directory for it, else make a file
        if an_obj.name == 'Group'
          obj_parsed[:type]     = :dir
          obj_parsed[:name]     = sanitized_obj_name_id
          obj_parsed[:children] = parse_fmp_obj(an_obj.path, object_nodes, obj_content) 
        else  
          obj_parsed[:content]  = one_file ? obj_content.call(objects) : obj_content.call(an_obj)
          obj_parsed[:yaml]     = one_file ? element2yaml(@report.xpath(object_base))     : element2yaml(an_obj)
        end
        
        objects_parsed.push(obj_parsed)
        break if one_file == true
      end
      objects_parsed
    end
    
    def write_obj_to_disk(objs, full_path)
      post_notification(full_path.gsub(%r{.*#{FMPVC.configuration.text_dirname}/},''), '  Writing')
      if full_path =~ %r{\.txt}
        # single file objects
        File.open(full_path, 'w') do |f|
          unless objs.empty? 
            f.write(objs.first[:content] + NEWLINE) unless objs.first[:content] == '' 
            f.write(NEWLINE + objs.first[:yaml])
          end
        end
      else
        # multi-file objects in directory
        FileUtils.mkdir_p(full_path) unless File.directory?(full_path)
        objs.each do |obj|
          if obj[:type] == :file
            File.open("#{full_path}/#{obj[:name]}", 'w') do |f|
              f.write(obj[:content] + NEWLINE) unless obj[:content] == ''
              f.write(NEWLINE + obj[:yaml])
            end
          elsif obj[:type] == :dir
            write_obj_to_disk(obj[:children], full_path + "/#{obj[:name]}")
          end
        end
      end
    end
    
    def define_content_procs
      
      @script_content = Proc.new do |a_script|
        content = ''
        a_script.xpath("./StepList/Step/StepText").each {|t| content += t.text.gsub(%r{\n},'') + "\n" } # remove \n from middle of steps
        content
      end
      
      @layouts_content = Proc.new do |a_layout|
        content = ''
        layout_name                  = a_layout['name']
        layout_id                    = a_layout['id']
        layout_table                 = a_layout.xpath('./Table').first['name']
        layout_theme                 = a_layout.xpath('./Theme').empty? ? '' : a_layout.xpath('./Theme').first['name']
        layout_format                = "%18s %-25s\n"
        object_format                = "                    %-16s  %-35s\n"
        content += format(layout_format, "Layout name: ", layout_name)
        content += format(layout_format, "id: ",          layout_id)
        content += format(layout_format, "Table: ",       layout_table)
        content += format(layout_format, "Theme: ",       layout_theme)
        content += NEWLINE
        content += format(layout_format, "Objects: ", '')
        layout_objects = a_layout.xpath("./*[name()='Object']")                   # find all objects
        layout_objects_types = layout_objects.map { |o| o['type']}                # list of 'types'
        if !layout_objects_types.empty?                                           # [].uniq! => nil - don't do that
          layout_objects_types.uniq! 
          content += format(object_format, "Type", "'Name'" )
          content += format(object_format, "----", "------" )
        end
        layout_objects_types.each do |a_type|
          selected_objects = layout_objects.select { |o| o['type'] == a_type }    # get all the objects of a given type
            selected_objects.each do |type_obj| # collect all objects of type
            content += format(object_format, type_obj['type'], type_obj.xpath('./*/Name').text) unless type_obj['type'] == "Text"
          end
        end
        
        content
      end


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
        table_format            = "%6d   %-25s   %-15s  %-15s   %-50s\n"
        table_header_format     = table_format.gsub(%r{d}, 's')
        content                 += format(table_header_format, "id", "Field Name", "Data Type", "Field Type", "Comment")
        content                 += format(table_header_format, "--", "----------", "---------", "----------", "-------")
        a_table.xpath(%{//BaseTable[@name=$table_name]/FieldCatalog/*[name()='Field']}, nil, :table_name => a_table['name']).each do |t| 
          t_comment             = t.xpath("./Comment").text
          content               += format(table_format, t['id'], t['name'], t['dataType'], t['fieldType'], t_comment)
        end
        content
      end

      @custom_function_content = Proc.new do |a_custom_function|
        content = ''
        content += a_custom_function.xpath("./Calculation").map {|t| t.text}.join(NEWLINE)
        content
      end
                       
      @menu_sets_content = Proc.new do |a_menu_set|
        content = ''
        menu_set_format                               = "%6d  %-35s\n"
        menu_set_header_format                        = menu_set_format.gsub(%r{d}, 's')
        content += format(menu_set_header_format, "id", "Menu")
        content += format(menu_set_header_format, "--", "----")
        a_menu_set.xpath("./CustomMenuList/*[name()='CustomMenu']").each do |a_menu|
          content += format(menu_set_format, a_menu['id'], a_menu['name'])
        end
        
        content
      end
      
      @custom_menus_content  = Proc.new do |a_menu|
        content = ''
        menu_name         = a_menu['name']
        menu_id           = a_menu['id']
        menu_base         = a_menu.xpath('./BaseMenu').empty? ? "" : a_menu.xpath('./BaseMenu').first['name']
        menu_comment      = a_menu.xpath('./Comment').text
        menu_format       = "%17s  %-35s\n"

        content += format(menu_format, "Menu name:", menu_name)
        content += format(menu_format, "id:", menu_id)
        content += format(menu_format, "Base menu:", menu_base)
        content += format(menu_format, "Comment:", menu_comment)
        content += NEWLINE
        menu_items = a_menu.xpath("./MenuItemList/*[name()='MenuItem']")
        menu_items.each do |an_item|
          an_item.xpath('./Command').each { |c| content += "  #{c['name']}\n"}
        end
        
        content
      end


      @accounts_content = Proc.new do |accounts|
        content = ''
          accounts_format        = "%6d  %-25s  %-10s  %-12s  %-20s  %-12s  %-12s  %-50s"
          accounts_header_format = accounts_format.gsub(%r{d}, 's')
          content += format(accounts_header_format, "id", "Name", "Status", "Management", "Privilege Set", "Empty Pass?", "Change Pass?", "Description") + NEWLINE
          content += format(accounts_header_format, "--", "----", "------", "----------", "-------------", "-----------", "------------", "-----------") + NEWLINE
          content += accounts.map do |an_account|
            account_name                                = an_account['name']
            account_id                                  = an_account['id']
            account_privilegeSet                        = an_account['privilegeSet']
            account_emptyPassword                       = an_account['emptyPassword']
            account_changePasswordOnNextLogin           = an_account['changePasswordOnNextLogin']
            account_managedBy                           = an_account['managedBy']
            account_status                              = an_account['status']
            account_Description                         = an_account.xpath('./Description').text
            format(
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
          end.join(NEWLINE)
          
        content
      end

      @privileges_content = Proc.new do |privileges|
        content = ''
        privileges_format        = "%6d  %-25s  %-8s  %-10s  %-15s  %-12s  %-12s  %-12s  %-8s  %-18s %-11s  %-10s   %-12s  %-10s   %-16s  %-10s  %-70s"
        privileges_header_format = privileges_format.gsub(%r{d}, 's')
        content += format(privileges_header_format, "id", "Name", "Print?", "Export?", "Manage Ext'd?", "Override?", "Disconnect?", "Password?", "Menus", "Records", "Layouts", "(Creation)", "ValueLists", "(Creation)", "Scripts", "(Creation)", "Description") + NEWLINE
        content += format(privileges_header_format, "--", "----", "------", "-------", "-------------", "---------", "-----------", "---------", "-----", "-------", "-------", "----------", "----------", "----------", "-------", "----------", "-----------") + NEWLINE
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
          
          content += format(
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
          ) + NEWLINE
        end
        content
      end
      
      @extended_priviledge_content = Proc.new do |ext_privileges|
        content = ''
        ext_privilege_format              = "%6d  %-20s  %-85s  %-150s\n"
        ext_privilege_header_format       = ext_privilege_format.gsub(%r{d}, 's')
        content += format(ext_privilege_header_format, "id", "Name", "Description", "Privilege Sets")
        content += format(ext_privilege_header_format, "--", "----", "-----------", "--------------")
        ext_privileges.each do |an_ext_privilege|
          ext_privilege_id                                    = an_ext_privilege['id']
          ext_privilege_name                                  = an_ext_privilege['name']
          ext_privilege_comment                               = an_ext_privilege['comment']
          ext_privilege_sets                                  = an_ext_privilege.xpath('./PrivilegeSetList/*[name()="PrivilegeSet"]').map {|s| s['name']}.join(", ")

          content += format(
                      ext_privilege_format \
                    , ext_privilege_id \
                    , ext_privilege_name \
                    , ext_privilege_comment \
                    , ext_privilege_sets \
          ) 
        end
        content
      end
      
      @relationships_content = Proc.new do |relationships|
        content = ''
        
        tables = @report.xpath("/FMPReport/File/RelationshipGraph/TableList/*[name()='Table']")
        table_format = "    %-25s  %-25s"
        content +="Tables\n"
        content += NEWLINE
        content +=format(table_format, "Base Table (id)", "Table occurrence (id)") + NEWLINE
        content +=format(table_format, "---------------", "---------------------") + NEWLINE
        content += NEWLINE
        tables.each do |a_table|
          table_id                                            = a_table['id']
          table_name                                          = a_table['name']
          basetable_id                                        = a_table['baseTableId']
          basetable_name                                      = a_table['baseTable']
          content +=format(table_format, "#{basetable_name} (#{basetable_id})", "#{table_name} (#{table_id})") + NEWLINE
        end
        content += NEWLINE

        relationship_format = "        %-35s  %-15s  %-35s"
        content +="Relationships" + NEWLINE
        relationships.each do |a_relationship|
          content += NEWLINE
          content += format("    Relationship: %-4d", a_relationship['id']) + NEWLINE
          predicates = a_relationship.xpath('./JoinPredicateList/*[name()="JoinPredicate"]')
          predicates.each do |a_predicate|
            predicate_type                                    = a_predicate['type']

            left_field                                        = a_predicate.xpath('./LeftField/*[name()="Field"]').first
            left_table                                        = left_field['table']
            left_field_name                                   = left_field['name']

            right_field                                       = a_predicate.xpath('./RightField/*[name()="Field"]').first
            right_table                                       = right_field['table']
            right_field_name                                  = right_field['name']
            content += format(relationship_format, "#{left_table}::#{left_field_name}", "#{predicate_type}", "#{right_table}::#{right_field_name}") + NEWLINE
          end
        end
        content
      end
      
      @file_access_content = Proc.new do |file_access|
        content = ''
        inbound_access                              = file_access.xpath("./Inbound/*[name()='InboundAuthorization']")
        outbound_access                             = file_access.xpath("./Outbound/*[name()='OutboundAuthorization']")
        access_format                               = "          %6d  %-25s  %-25s  %-25s"
        access_format_header                        = access_format.gsub(%r{d}, 's')

        auth_requirement = file_access.first['requireAuthorization']
        content += "Authorization required: #{auth_requirement}" + NEWLINE
        if auth_requirement == "True"
          content += NEWLINE
          content += format(access_format_header, "id", "Timestamp", "Account", "Filenames") + NEWLINE
          content += format(access_format_header, "--", "---------", "-------", "---------") + NEWLINE
          content += format("%12s", "Inbound:") + NEWLINE
          inbound_access.each do |i|
            content += format(access_format, i['id'], i['date'], i['user'], i['filenames']) + NEWLINE
          end
          content += format("%12s", "Outbound:") + NEWLINE
          outbound_access.each do |o|
            content += format(access_format, o['id'], o['date'], o['user'], o['filenames']) + NEWLINE
          end
        end
        content += NEWLINE

        content
      end
      
      @external_sources_content = Proc.new do |data_sources|
        content = ''
        file_references                           = data_sources.xpath("./*[name()='FileReference']")
        odbc_sources                              = data_sources.xpath("./*[name()='OdbcDataSource']")
        file_references_format                    = "   %6d  %-25s  %-25s\n"
        file_references_header_format             = file_references_format.gsub(%r{d},'s')
        odbc_source_format                        = "   %6d  %-25s  %-25s  %-25s\n"
        odbc_source_header_format                 = odbc_source_format.gsub(%r{d},'s')

        content += format(file_references_header_format, "id", "File Reference", "Path List")
        content += format(file_references_header_format, "--", "--------------", "---------")
        file_references.each do |r|
          content += format(file_references_format, r['id'], r['name'], r['pathList'])
        end
        content += NEWLINE
        content += format(odbc_source_header_format, "id", "ODBC Source", "DSN", "Link")
        content += format(odbc_source_header_format, "--", "-----------", "---", "----")
        odbc_sources.each do |s|
          content += format(odbc_source_format, s['id'], s['name'], s['DSN'], s['link'])
        end
        
        content
      end
      
      @file_options_content = Proc.new do |file_options|
        content = ''
        file_options_format                        = "    %-27s  %-30s\n"
        trigger_format                             = "        %-23s  %-30s\n"
      
        # optional <FMPReport><File><Options>, see DDR_grammar doc, p. 5
        open_account_search                        = file_options.xpath('./OnOpen/Account')
        open_account                               = (open_account_search.size > 0 ? open_account_search.first['name']: "")
        open_layout_search                         = file_options.xpath('./OnOpen/Layout')
        open_layout                                = ( open_layout_search.size > 0 ? open_layout_search.first['name'] : "" )
        
        # puts "encryption: >>#{file_options.xpath('./Encryption').empty?}<<"
        encryption_type                            = file_options.xpath('./Encryption').empty? ? '' : file_options.xpath('./Encryption').first['type']
        encryption_note                            = case encryption_type
                                                     when ""
                                                     when "0"
                                                       "no encryption"
                                                     when "1"
                                                       "AES256 encrypted"
                                                     end
        minimum_allowed_version                    = file_options.xpath('./OnOpen/MinimumAllowedVersion').empty? ? '' : file_options.xpath('./OnOpen/MinimumAllowedVersion').first['name']
        content += "File Options\n"
        content += "------------\n"
        content += NEWLINE
        content += format(file_options_format, "Encryption:", "#{encryption_type} (#{encryption_note})")
        content += NEWLINE
    		content += format(file_options_format, "Minimum Allowed Version:", minimum_allowed_version)
    		content += format(file_options_format, "Account:", open_account)
    		content += format(file_options_format, "Layout:", open_layout)
        content += NEWLINE
        content += format(file_options_format, "Default Custom Menu Set:", file_options.xpath('./DefaultCustomMenuSet/CustomMenuSet').first['name'])
        content += NEWLINE
        content += "    Triggers\n"
        file_options.xpath('./WindowTriggers/*').each do |t|
          content += format(trigger_format, t.name, t.xpath('./Script').first['name'])
        end
        
        content
      end
      
      @themes_content = Proc.new do |themes|
        content = ''
        theme_format = "  %6s  %-20s  %-20s  %-10s  %-10s  %-20s\n"
        content += format(theme_format, "id", "Name", "Group", "Version", "Locale", "Internal Name")
        content += format(theme_format, "--", "----", "-----", "-------", "------", "-------------")
        themes.each do |a_theme|
          content += format(theme_format, a_theme['id'], a_theme['name'], a_theme['group'], a_theme['version'], a_theme['locale'], a_theme['internalName'])
        end
        
        content
      end
      
    end


  end

end


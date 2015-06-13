module FMPVC
  
  require 'nokogiri'
  require 'fileutils'
  
  class FMPReport
    
    attr_reader :content, :type, :text_dir, :text_filename, :report_dirpath
    
    def initialize(report_filename, ddr)
      report_dirpath    = "#{ddr.base_dir}/#{report_filename}"  # location of the fmpfilename.xml file
      raise(RuntimeError, "Error: can't find the report file, #{report_dirpath}") unless File.readable?(report_dirpath)
      
      @content          = IO.read(report_dirpath, mode: 'rb:UTF-16:UTF-8') # transcode is specifically for a spec content match
      @text_dir         = "#{ddr.base_dir}../fmp_text"
      @text_filename    = fs_sanitize(report_filename)
      @report_dirpath   = "#{@text_dir}/#{@text_filename}"
      @scripts_dirpath  = @report_dirpath + "/Scripts"
      
      self.parse
      self.clean_dir
      self.write_dir
      self.write_scripts
      
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
        FileUtils.mkdir_p(this_script_disk_path) unless File.readable?(this_script_disk_path)
        
        # write the text value of the script line to the new script file
        sanitized_script_name        = fs_sanitize(script_name)
        sanitized_script_name_id     = fs_id(sanitized_script_name, script_id)
        sanitized_script_name_id_ext = sanitized_script_name_id + '.txt'
        File.open(this_script_disk_path + "/#{sanitized_script_name_id_ext}", 'w') do |f| 
          a_script.xpath("./StepList/Step/StepText").each {|t| f.puts t.text.gsub(%r{\n},'') } # remove \n from middle of steps
        end
      end
    end
    
    
    
  end

end


module FMPVC
  
  require 'nokogiri'
  require 'fileutils'
  
  class FMPReport
    
    attr_reader :content, :type, :text_dir, :text_filename, :report_dirpath
    
    def initialize(report_filename, ddr)
      report_dirpath = "#{ddr.base_dir}/#{report_filename}"  # location of the fmpfilename.xml file
      raise(RuntimeError, "Error: can't find the report file, #{report_dirpath}") unless File.readable?(report_dirpath)
      
      @content = IO.read(report_dirpath, mode: 'rb:UTF-16:UTF-8') # transcode is specifically for a spec content match
      @text_dir = "#{ddr.base_dir}../fmp_text"
      @text_filename = fs_sanitize(report_filename)
      @report_dirpath = "#{@text_dir}/#{@text_filename}"
      @scripts_dirpath = @report_dirpath + "/Scripts"
      
      self.parse
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
      text_string.gsub(%r{[.\/\\]}mx, '_') # just remove [ . / \ ] for now.
    end
    
    # e.g. /FMPReport/File/ScriptCatalog , /FMPReport/File/ScriptCatalog/Group[1]/Group
    # return: "/Actors/Actor Triggers"
    def disk_path_from_base(object_base, object_xpath, path = '')
      return "#{path}" if object_xpath == object_base
      curent_node_filename = @report.xpath("#{object_xpath}").first['name']
      parent_node_xpath = @report.xpath("#{object_xpath}/..").first.path
      disk_path_from_base(object_base,  parent_node_xpath, "/#{curent_node_filename}" + "#{path}" )
    end
    
    def write_dir
      # raise(RuntimeError, "Error: there is no text output base dir (e.g. /fmp_text)") unless File.readable?(@text_dir)  # needed with _p?
      FileUtils.mkdir_p(@report_dirpath)
    end
    
    def write_scripts(object_xpath = '/FMPReport/File/ScriptCatalog')
      current_disk_folder = disk_path_from_base('/FMPReport/File/ScriptCatalog', object_xpath)
      
      script_groups = @report.xpath("#{object_xpath}/*[name()='Group']")
      script_groups.each do |a_folder|
        full_folder_path = @scripts_dirpath + "#{current_disk_folder}/#{a_folder['name']}"
        FileUtils.mkdir_p(full_folder_path)
        write_scripts(a_folder.path)
      end
      
      scripts = @report.xpath("#{object_xpath}/*[name()='Script']")
      scripts.each do |a_script|
        script_name = a_script["name"]
        this_script_disk_path = @scripts_dirpath + "/#{current_disk_folder}"
        FileUtils.mkdir_p(this_script_disk_path) unless File.readable?(this_script_disk_path)
        
        # write the text value of the script line to the new script file
        File.open(this_script_disk_path + "/#{script_name}.txt", 'w') do |f| 
          a_script.xpath("./StepList/Step/StepText").each {|t| f.puts t.text.gsub(%r{\n},'') } # remove \n from middle of steps
        end
      end
    end
    
  end

end

#  can FMP folders have scripts and folders with same name?  rename 2nd one with a DUP suffix
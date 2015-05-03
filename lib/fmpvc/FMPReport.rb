module FMPVC
  
  require 'nokogiri'
  require 'fileutils'
  
  class FMPReport
    
    attr_reader :content, :type, :text_dir, :text_filename, :report_filepath
    
    def initialize(report_filename, ddr)
      report_filepath = "#{ddr.base_dir}/#{report_filename}"  # location of the fmpfilename.xml file
      raise(RuntimeError, "Error: can't find the report file, #{report_filepath}") unless File.readable?(report_filepath)
      
      @content = IO.read(report_filepath, mode: 'rb:UTF-16:UTF-8') # transcode is specifically for a spec match
      @text_dir = "#{ddr.base_dir}../fmp_text"
      @text_filename = fs_sanitize(report_filename)
      @report_filepath = "#{@text_dir}/#{@text_filename}"
      
      self.parse
      
    end

    def parse
      report = Nokogiri::XML(@content)
      @type = report.xpath("//FMPReport").first["type"]
      
      # the report should be a "Report" type
      raise RuntimeError, "Incorrect file type: not an FMPReport Report file" unless @type == "Report"

    end

    def fs_sanitize(text_string)
      text_string.gsub(%r{[.\/\\]}mx, '_') # just remove [ . / \ ] for now.
    end
    
    def write_dir
      # raise(RuntimeError, "Error: there is no text output base dir (e.g. /fmp_text)") unless File.readable?(@text_dir)  # needed with _p?
      FileUtils.mkdir_p(@report_filepath)
    end
    
  end

end

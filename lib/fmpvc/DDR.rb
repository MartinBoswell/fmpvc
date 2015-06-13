module FMPVC
  
  require 'nokogiri'
  
  class DDR
    
    attr_reader :content, :type, :fmp_files, :xml_files, :base_dir, :reports
    
    def initialize(summary_directory, summary_filename = "Summary.xml")

      @base_dir = File.expand_path(summary_directory)
      raise(RuntimeError, "Error: can't find the DDR directory, #{@base_dir}") unless File.readable?(@base_dir)
      summary_file_path = "#{@base_dir}/#{summary_filename}"
      raise(RuntimeError, "Error: can't find the DDR Summary.xml file, #{summary_file_path}") unless File.readable?(summary_file_path)

      @content = IO.read(summary_file_path)
      self.parse
      
    end
    
    def parse
      summary = Nokogiri::XML(@content)
      @type = summary.xpath("//FMPReport").first["type"]

      if @type != "Summary"
        raise RuntimeError, "Incorrect file type: not a DDR Summary.xml file!"
      end
      
      # create list of files in this DDR
      fmp_reports   = summary.xpath("//FMPReport/File")  
      @xml_files    = fmp_reports.collect {|node| node['link']}
      @fmp_files    = fmp_reports.collect {|node| node['name']}      
      
    end
    
    def process_reports
      @reports = Array.new
      @xml_files.each do |report_file|
        @reports.push FMPReport.new(report_file, self)
      end
      @reports
    end
    
    def write_reports
      @reports.each { |r| r.write_all_objects }
    end

  end

end

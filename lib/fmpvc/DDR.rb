module FMPVC
  
  require 'nokogiri'
  
  class DDR
    
    attr_reader :content, :type, :fmp_files, :base_dir
    
    def initialize(summary_directory, summary_filename = "Summary.xml")
      @base_dir = File.expand_path(summary_directory)
      # Check that directory exists and the summary file exists (whatever its name)
      raise(RuntimeError, "Error: can't find the DDR directory, #{@base_dir}") unless File.readable?(@base_dir)
      summary_file_path = "#{@base_dir}/#{summary_filename}"
      raise(RuntimeError, "Error: can't find the DDR Summary.xml file, #{summary_file_path}") unless File.readable?(summary_file_path)

      @content = IO.read(summary_file_path)

      
      self.parse
    end
    
    
    # private
    
    def parse
      summary = Nokogiri::XML(@content)
      @type = summary.xpath("//FMPReport").first["type"]

      # a DDR should only be produced from a Summary.xml file (whatever it's called)
      if @type != "Summary"
        raise RuntimeError, "Incorrect file type: not a DDR Summary.xml file!"
      end
      
      # create list of files in this DDR
      fmp_reports = summary.xpath("//FMPReport/File")  # Nokogiri::XML::NodeSet
      @fmp_files = Array.new # change to @fmp_files = fmp_reports.collect{ |each_node| each_node["name"]}
      fmp_reports.each do |a_file|
        @fmp_files.push(a_file["name"])
      end
      
      # 
      
      
    end
    
    
    
  end

end

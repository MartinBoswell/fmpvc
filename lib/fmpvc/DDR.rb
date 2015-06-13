module FMPVC
  
  require 'nokogiri'
  
  # for xml2yaml
  require 'active_support/core_ext/hash/conversions'
	require 'yaml'

  class DDR
    
    attr_reader :content, :type, :fmp_files, :xml_files, :base_dir_ddr, :base_dir_text_path, :reports, :fmpa_version, :creation_time, :creation_date, :reports
    
    def initialize(summary_directory, summary_filename = "Summary.xml")
      
      @summary_filename      = summary_filename
      @base_dir_ddr          = File.expand_path(summary_directory)    ; raise(RuntimeError, "Error: can't find the DDR directory, #{@base_dir_ddr}")            unless File.readable?(@base_dir_ddr)
      summary_file_path      = "#{@base_dir_ddr}/#{summary_filename}" ; raise(RuntimeError, "Error: can't find the DDR Summary.xml file, #{summary_file_path}") unless File.readable?(summary_file_path)
      @base_dir_text_path    = @base_dir_ddr.gsub(%r{fmp_ddr}, 'fmp_text')
      @summary_text_path     = "#{@base_dir_text_path}/#{summary_filename.gsub(%r{\.xml}, '.txt')}"

      @content               = IO.read(summary_file_path)
      @reports               = Array.new
      self.parse
      
    end
    
    def parse
      summary          = Nokogiri::XML(@content)
      attrs            = summary.xpath("//FMPReport").first # "there can be only one"
      @type            = attrs["type"] ; raise RuntimeError, "Incorrect file type: not a DDR Summary.xml file!" unless @type == "Summary"
      @fmpa_version    = attrs["version"]
      @creation_time   = attrs["creationTime"]
      @creation_date   = attrs["creationDate"]
      @summary_yaml    = element2yaml(summary)
      
      fmp_reports      = summary.xpath("//FMPReport/File")
      @reports         = fmp_reports.map do |a_report|
        {              
          :name        => a_report['name'], 
          :link        => a_report['link'],
          :path        => a_report['path'],
          :attrs       => Hash[ a_report.xpath("./*").map {|v| [v.name, v['count']]} ]
        }
      end      
      @xml_files       = fmp_reports.collect {|node| node['link']}
      @fmp_files       = fmp_reports.collect {|node| node['name']}
    end
    
    def process_reports
      @reports.each do |r| 
        # $stdout.puts
        post_notification(r[:link].gsub(%r{\./+},''), 'Processing')
        r[:report] = FMPReport.new(r[:link], self) 
      end
    end
    
    def post_notification(object, verb = 'Updating')
      $stdout.puts [verb, object].join(" ") unless FMPVC.configuration.quiet
    end
    
    def stringer(n, str = " ")
      n.times.map {str}.join
    end
    
    def write_summary
      FileUtils.mkdir(@base_dir_text_path) unless File.directory?(@base_dir_text_path)
      summary_format      = "%25s  %-512s\n"
      # report_params       = ["BaseTables", "Tables", "Relationships", "Privileges", "ExtendedPrivileges", "FileAccess", "Layouts", "Scripts", "ValueLists", "CustomFunctions", "FileReferences", "CustomMenuSets", "CustomMenus"]
      report_params       = @reports.first[:attrs].keys # better to get the keys dynamically than a fixed list
      params_label        = report_params.map {|p| "%-2s" + stringer(p.length) }.join()
      report_format       = "%25s " + params_label
      header              = stringer(25 - "Report".length) + "Report" + "   " + report_params.join('  ')
      separator           = header.gsub(%r{\w}, '-')
      File.open(@summary_text_path, 'w') do |f|
        f.write format(summary_format, "Summary file:",           @summary_filename)
        f.write format(summary_format, "Summary path:",           @base_dir_ddr)
        f.write format(summary_format, "FileMaker Pro version:",  @fmpa_version)
        f.write format(summary_format, "Creation Date:",          @creation_date)
        f.write format(summary_format, "Creation Time:",          @creation_time)
        f.puts
        f.puts header
        f.puts separator
        @reports.each do |r|
          f.puts format(report_format, r[:name] + ' ', *report_params.map { |p| r[:attrs][p] }) 
        end
        f.puts
        f.puts @summary_yaml
      end
    end
    
    def write_reports
      self.process_reports if @reports.first[:report].nil?
      @reports.each { |r| r[:report].write_all_objects }
    end
    
    def element2yaml(xml_element)
  		element_xml							= xml_element.to_xml({:encoding => 'UTF-8'}) # REMEMBER: the encoding
  		element_hash						= Hash.from_xml(element_xml)
  		element_yaml						= element_hash.to_yaml
    end
    
  end

end

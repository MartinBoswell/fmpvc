#!/usr/bin/env ruby

puts "Hello, Cleveland!"

require 'nokogiri'
# require_relative '../lib/fmpvc/DDR.rb'
# puts __FILE__ # => bin/fmp_versioning.rb
# puts File.dirname(__FILE__)
# Dir.glob("*").each {|f| puts f }  # qw%{bin lib spec}
Dir.glob("lib/**/*.rb" ).each do |f|
  # puts f  #  => lib/fmpvc/DDR.rb
  require_relative "../#{f}"
end


include FMPVC

###
# capture ddr
###
new_ddr = DDR.new("./spec/data/test_1/ddr")
puts "Read new DDR of type: #{new_ddr.type}"
puts "The base directory is: #{new_ddr.base_dir}"
puts "With #{new_ddr.filenames.size} file#{new_ddr.filenames.size > 1 ? "s" : ""}: "
new_ddr.filenames.each { |filename| puts "   #{filename}"}


###
# new_ddr.files.each
###
ddr_reports = Array.new
new_ddr.filenames.each do |a_report|
  
  # create an FMPReport object
  new_report = FMPReport.new(a_report)
  # which reads in filename file

  ###
  # create or clear the directory for this report
  ###

  ###
  # optionally write a file with metadata info: size, mod dates, extra info
  ###
  
  ###
  # for each dataset type (that exists)
  ###
  
    # create dataset folder
    # for each dataset
    #   check sanitized filenames for collisison
    #   write data to file
    #
end





module FMPVC
  class Configuration
   
   attr_accessor :quiet, :yaml, :ddr_dirname, :ddr_filename, :ddr_basedir, :text_dirname, :tree_filename
   
   def initialize
     # set default config settings
     @quiet               = false               # don't print progress to stdout
     @yaml                = true                # append full YAML to text files
     @ddr_filename        = 'Summary.xml'       # name of primary DDR file to open
     @ddr_dirname         = 'fmp_ddr'           # directory containing DDR 
     @ddr_basedir         = './'                # base directory (containing fmp_ddr, fmp_text)
     @text_dirname        = 'fmp_text'          # text file base directory
     @tree_filename       = 'tree.txt'          # set to nil to disable tree file generation
   end
    
  end
end
module FMPVC
  class Configuration
   
   attr_accessor :quiet, :yaml, :ddr_dirname, :ddr_filename, :text_dirname, :tree_filename
   
   def initialize
     # set default config settings
     @quiet               = false
     @yaml                = true
     @ddr_filename        = 'Summary'
     @ddr_dirname         = 'fmp_ddr'
     @text_dirname        = 'fmp_text'
     @tree_filename       = 'tree.txt'
   end
    
  end
end
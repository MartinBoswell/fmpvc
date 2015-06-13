module FMPVC
  class Configuration
   
   attr_accessor :quiet, :yaml, :ddr_dirname, :ddr_filename, :text_dirname, :tree_filename
   
   def initialize
     # set default config settings
     @quiet               = false        # don't print progress to stdout
     @yaml                = true         # append full YAML to text files
     @ddr_filename        = 'Summary'
     @ddr_dirname         = 'fmp_ddr'
     @text_dirname        = 'fmp_text'
     @tree_filename       = 'tree.txt'   # set to nil to disable tree file generation
   end
    
  end
end
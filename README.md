# FMPVC

`FMPVC` is a tool to help a FileMaker developer by creating a textual representation of their databases.  The command, `fmpvc`, parses a Database Design Report (DDR) produced by FileMaker Pro Advanced and creates text files for each of the primary FileMaker objects described in the DDR.  With those files the developer may:

1. use a version control system to track changes to databases
1. diff current objects with objects from previous versions (e.g. compare different versions of a script)
2. perform full text searches of a set of FileMaker datases (e.g. find all uses of a custom function in a solution)
3. obtain text representations of FileMaker objects (e.g. create a list of fields in a table)

DDR parsing is a one-way process, and there is currently no way to re-create a FileMaker file from DDR, and therefore, there is no way to restore, for instance, an old version of a FileMaker Script.  The best we can do is examine the old version and recreate it manually.  It is recommended that developers save clones of the FileMaker databases with each version control commit so that older versions of some of the items may be copied into newer versions (or, of course, entire databases may be restored).


## Installation

Install the `FMPVC` gem as follows:

    $ gem install fmpvc

`FMPVC` requires both Nokogiri and ActiveSupport gems.

`FMPVC` requires ruby x.y.z or later.  FMPVC has only been tested on Mac OS X, and in it's current state, it is unlikely to work properly in Windows' ruby environments.

## Usage

By default the `fmpvc` command looks for a `Summary.xml` file in a directory called `fmp_ddr` in the current working directory.  It reads the contents of that file and then processes each of the referenced report files (there is one for each FileMaker file included in the DDR).  It produces a set of text files and directories representing each database inside of the directory, `fmp_text`.  Example output looks like this:

		├── fmp_clone/
		│   └── FMServer_Sample Clone.fmp12
		├── fmp_ddr/
		│   ├── FMServer_Sample_fmp12.xml
		│   └── Summary.xml
		├── fmp_text/
		│   └── FMServer_Sample_fmp12.xml/
		│       ├── Accounts.txt
		│       ├── CustomFunctions/
		│       │   └── GetWorkDays (id 1).txt
		...etc.

In short:

- change directory to the location where you'd like to save the DDR and clones and produce the text files
- create a directory, `fmp_ddr`, to hold DDR
- from FileMaker Pro Advanced, choose "Database Design Report..." from the Tools menu.  
	- choose project database files
	- include all tables for each file
	- include all DDR sections
	- choose XML output
	- save in the folder created above with the default name, `Summary`
- optionally, save clones of the same databases in a folder named, `fmp_clone` (this is not required)
- run the command `fmpvc`

Command-line options:

		-q quiet
		-Y no YAML





## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/fmpvc/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

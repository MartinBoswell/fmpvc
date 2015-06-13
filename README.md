# FMPVC

FMPVC is a tool to help a FileMaker developer use a version control system.  The command, `fmpvc` parses a Database Design Report (DDR) produced by FileMaker Pro Advanced and creates text files for each of the primary FileMaker objects described in the DDR.  With those files the developer may:

1. use a version control system to track changes to databases
1. diff current objects with objects from previous versions (e.g. compare different versions of a script)
2. perform full text searches of a set of FileMaker datases (e.g. find all uses of a custom function in a solution)
3. obtain text representations of FileMaker objects (e.g. create a list of fields in a table)

DDR parsing is a one-way process, and there is currently no way to re-create a FileMaker file from DDR, and therefore, there is no way to restore, for instance, an old version of a FileMaker Script.  The best we can do is examine the old version and recreate it manually.  It is recommended that users save clones of the FileMaker databases with each version control commit so that older versions of some of the items may be copied into newer versions (or, of course, entire databases may be restored).


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fmpvc'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fmpvc

## Usage

TODO: Write usage instructions here

In short:

- create directory to hold DDR (and, optionally, cloned databases)
- from a shell (Terminal window)
	- cd 
	- gem install fmpvc


Naive instructions:

- 


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release` to create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

1. Fork it ( https://github.com/[my-github-username]/fmpvc/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

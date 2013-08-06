require 'rubygems'
require 'data_mapper'
require 'dm-migrations'
require 'dm-aggregates'
require_relative '../lib/bookie/helpers'

#DataMapper::Logger.new($stdout, :debug)

# For now store in a local file
default_dbfile = "#{File.expand_path('..', File.dirname(__FILE__))}/bookie.db"
dbfile = File.expand_path(config['file_path']) || default_dbfile
uri = "sqlite://#{dbfile}"

DataMapper.setup(:default, uri)

require_relative 'account'
require_relative 'bill'
require_relative 'category'
require_relative 'cycle'
require_relative 'transaction'
require_relative 'transfer'

#DataMapper::Model.raise_on_save_failure = true
DataMapper.finalize
DataMapper.auto_upgrade!


require 'rubygems'
require 'bundler/setup'
require 'couchrest'
require 'couchrest_model'
require 'sunspot'
require 'sunspot/rails'
require 'sinatra'
require 'highline/import'
require './globals.rb'
require './couchrest_sunspot.rb'

case
when ENV['CLOUDANT_URL']
  puts "Logging in with #{ENV['CLOUDANT_URL']}"
  set :db, CouchRest.database( "#{ENV['CLOUDANT_URL']}/#{RELNAME}" )
when ENV['LOCALCOUCH_URL']
  puts "Logging in with #{ENV['LOCALCOUCH_URL']}"
  set :db, CouchRest.database( "#{ENV['LOCALCOUCH_URL']}/#{RELNAME}" )
else
  print "CouchDB Username: "
  username = gets.chomp
  password = ask("Password: ") { |q| q.echo = false }
  server = ask("Server URL: ") { |q| q.echo = true }
  database = ask("Database name: ") { |q| q.echo = true }
  localURL = "http://".concat("#{username}:#{password}@#{server}/#{database}")
  set :db, CouchRest.database!(localURL)
end

# A class that defines what a topic is
class Topic < CouchRest::Model::Base
  include Sunspot::Couch
  use_database settings.db

  ## Set the properties ##
  # Version added
  property :version_added, Float
  # Version removed
  property :version_removed, Float, :default => CURRENT_PATCH

  # API Version added
  property :api_version_added, Float
  # API Version removed
  property :api_version_removed, Float, :default => CURRENT_API_VERSION

  property :topicname, String

  # Hash to determine if the attachment has changed
  property :attachment_hash, String

  # Metadata
  property :locale, String
  property :app_area, String
  property :product, String
  property :role, String
  property :edition, String
  property :topic_type, String
  property :identifier, String
  property :technology, String
  property :doctype, String
  property :maintitle, String
  property :homelink, String

  # Need to add the text from the attachment for solr searching
  property :content, String
  property :title, String
  property :perm_and_edition_tables, String
  timestamps!

  ## The design documents
  design do
    view :by_id
    view :by_topicname
    view :by_identifier
    view :by_topicname_and_locale
    view :by_maintitle
    view :by_technology
  end

  searchable do
    text :content, :stored => true
    text :perm_and_edition_tables, :stored => false
    text :title, :stored => true
    text :technology, :stored => true
    text :doctype, :stored => true
    text :maintitle, :stored => true
    text :homelink, :stored => true
    string :app_area, :stored => true, :multiple => true
    string :edition, :stored => true, :multiple => true
    string :identifier, :stored => true
    string :locale, :stored => true
    string :product, :stored => true, :multiple => true
    string :role, :stored => true, :multiple => true
    string :topicname, :stored => true
    time :updated_at, :stored => true
    integer :api_version_removed, :stored => true
    string :version_removed, :stored => true
  end
end

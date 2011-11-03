require 'highline/import'
require 'sinatra'

# Define which CouchDB instance to use.
# Creates the database if it does not exist already.
# For LOCALCOUCH_URL, a typical setting is http://admin:[password]@127.0.0.1:5984
case
when ENV['CLOUDANT_URL']
  puts "Logging in with #{ENV['CLOUDANT_URL']}"
  set :db, CouchRest.database!( "#{ENV['CLOUDANT_URL']}/summer11" )
when ENV['LOCALCOUCH_URL']
  puts "Logging in with #{ENV['LOCALCOUCH_URL']}"
  set :db, CouchRest.database!( "#{ENV['LOCALCOUCH_URL']}/summer11" )
else
  print "Username: "
  username = gets.chomp
  password = ask("Password: ") { |q| q.echo = false }
  server = ask("server: ") { |q| q.echo = true }
  database = ask("database: ") { |q| q.echo = true }
  localURL = "http://".concat("#{username}:#{password}@#{server}/#{database}")
  set :db, CouchRest.database!(localURL)
end

# Authentication
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == ['devdoc', 'test1234']
end


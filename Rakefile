require 'sunspot/rails/tasks'
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/r18n'
require 'couchrest'
require 'couchrest_model'
require 'nokogiri'
require 'haml'
require 'dalli'
require './topic_model'
require './couchrest_sunspot'
require './server_info'

task :environment do
  Sinatra::Application.environment = ENV['RACK_ENV']
end
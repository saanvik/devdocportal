# encoding: utf-8
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/r18n'
require 'couchrest'
require 'nokogiri'
require 'haml'
require './topic_model'
require './couchrest_sunspot'
require './server_info'


######################################################################
# @author Steve Anderson                                             #
# Set the routes for dbcom                                           #
######################################################################

# Visit at, for example, http://couch-rest-289.heroku.com/dbcom/en/us/customviews.htm

# Views (in the views directory) are defined using haml
# http://haml-lang.com
set :haml, :format => :xhtml

# Set up the index info
# The environment variable is auto-set on Heroku.
# If it's not set, allow the user to set it manually.  This is important for testing.
# case
# when ENV['INDEXTANK_API_URL']
#   client = IndexTank::Client.new(ENV['INDEXTANK_API_URL'])
# else
#   print "Indextank API URL: "
#   indextank_api_url = gets.chomp
#   client = IndexTank::Client.new(indextank_api_url)
# end

# index = client.indexes(INDEXNAME)

case
when ENV['WEBSOLR_URL']
  Sunspot.config.solr.url =ENV['WEBSOLR_URL']
when ENV['LOCALSOLR_URL']
  Sunspot.config.solr.url =ENV['LOCALSOLR_URL']
end
puts "Indexing with #{Sunspot.config.solr.url}"

# Sinatra helpers go here
helpers do
  # A Sinatra helper to get the MIME type for an
  # attachment/file/whatever, the set the content_type for the route
  # based on the extension passed in.
  # @param extension - The extension type of the file who's MIME type we are trying to find.
  def set_content_type(extension)
    begin
      content_type Rack::Mime.mime_type(extension)
    rescue
      STDERR.puts "Couldn't find the MIME type for #{extension}."
    end
  end
end


######################################################################
# Routes here
######################################################################

####
# Ignore the following
####

# This is a bad path for help.css, so ignore it if it's called
# @todo If the help build is changed, this may not be required.
get '*${CSS.PATH}help.css' do
  ""
end

# We're not using the app functions javascript file, so ignore it if it's called
# @todo If the help build is changed, this may not be required.
get '/js/functions.js' do
  ""
end

# We're not using this feedback form, so ignore it if it's called
# @todo If the help build is changed, this may not be required.
get '*form.htm' do
  ""
end

get '*favicon.ico' do
  ""
end

####
# End ignores
####

# Import for oocss stylesheets
get '/*/oocss/*' do | discard, path |
    set_content_type(path[/(?:.*)(\..*$)/, 1])
    @thiscss = Topic.by_topicname_and_locale.key(["oocss", "en-us"]).first
    return @thiscss.read_attachment(path)
end

get '/oocss/*' do | path |
  set_content_type(path[/(?:.*)(\..*$)/, 1])
  @thiscss = Topic.by_topicname_and_locale.key(["oocss", "en-us"]).first
  puts "In the oocss run, looking for #{path}"
  return @thiscss.read_attachment(path)
end


# All calls to help.css should go to the same file
get '*help.css' do
  content_type 'text/css'
  @thiscss = Topic.by_topicname_and_locale.key(["help.css", "en-us"]).first
  return @thiscss.read_attachment("help.css")
end

# All calls to /img should grab it from the app_image_document
get '/img/*' do | path |
    set_content_type(path[/(?:.*)(\..*$)/, 1])
    @thistopic = Topic.by_topicname_and_locale.key(["app_image_document","en-us"]).first
    return @thistopic.read_attachment('/img/'.concat(path))
end

# Facet and Query test
#get %r{/dbcom\/(.*)\/search/(.+)/facet/(.+)} do |locale,query,facet|
#   "Hello, #{query} in #{locale}, with a facet of #{facet}"
#end

# For simple pages (not the three pane layout) top_level view replaces
# the layout view for simple pages
get '/dbcom/:locale/' do
  @locale = params[:locale]
  haml :index, :layout => :simple_layout
end

# Actual search URL
# @todo Do queries need to be escaped to be safe?
get %r{/(.*)\/(.*)\/search/(.+)} do |root,locale,query|
  @topictitle = t.title.searchresults
  @sidebartitle = t.title.facets

  # @todo Add the checkboxes here
  @sidebarcontent = "List of facets, with checkboxes"

  puts "Searching for #{query}"
  puts "Using #{Sunspot.config.solr.url}"
  @search=Sunspot.search(Topic) do
    keywords query do
      highlight :content
    end
    facet :app_area
  end
  @results = @search.results
  puts "Found #{@results.length} topics with the query #{query}"
  haml :search, :locals => {:locale => locale, :root => root}
end

# Search only page
get '/dbcom/:locale/search' do
  # @todo Search only page should go back to the landing page
  haml :search_info
end

# Grab the search and return a page with the results
post %r{/([^\/]*)\/([^\/]*)\/.*} do |root,locale|
  query = params[:search_query]
  puts "Searching for #{query}"
  puts "Using #{Sunspot.config.solr.url}"
  @search=Sunspot.search(Topic) do
    keywords query do
      highlight :content
    end
    facet :app_area
  end
  @results = @search.results
  puts "Found #{@results.length} topics with the query #{query}"
  haml :search, :locals => {:locale => locale, :root => root}
end

# Go to the search page, nothing but the search
get '/dbcom/:locale/search/' do
  haml :search_info
end

# Calls to <root>/dbcom/<lang>/<locale>/<topicname> get redirected
# based on the locale key in couchdb
# Need to support URLs of the format
# http://docs.databse.com/dbcom?locale=en-us&target=<filename>&section=<section>
# This doesn't work.  I'll need to use a regexp

#([^\/]*)\?locale=([^\&]*)\&target=([^\&]*)\&section=(.*)
#get 'dbcom?locale=:locale&target=:topicname&section=:section' do |locale,topicname,section|

# So the trick is, everything after the question mark gets pushed into the params hash, like this
# {"params":{"locale":"en-us","target":"filename","section":"section"}}

get %r{/(^\?)*} do
#get %r{/([^\/]*).locale=([^\&]*)\&target=([^\&]*)\&section=(.*)} do |root,locale,topicname,section|
#get '/dbcom/:locale/:topicname' do
  puts "#{request.url}"
  locale = "#{params[:locale]}"
  topicname = "#{params[:target]}"
  section = "#{params[:section]}"
#  puts "root: #{root}"
  puts "locale: #{locale}"
  puts "topicname: #{topicname}"
  puts "section: #{section}"
  @thistopic = Topic.by_topicname_and_locale.key([params[:target], params[:locale]]).first

  @thisdoc = Nokogiri::XML(@thistopic.read_attachment(params[:target]))
  @content=@thisdoc.xpath('//body').children().remove_class("body")
  @topictitle=@thisdoc.xpath('//title[1]').inner_text()
  # Placeholders
  # @todo - Use labels for this one
  @sidebartitle =t.title.toc
  # "Table of Contents"
  # @todo Replace this with the generated version
  @sidebarcontent = t.toc
    #"List of headers, with links"
  haml :topic
#  return @thistopic.read_attachment(params[:topicname])
end

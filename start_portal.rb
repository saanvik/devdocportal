# encoding: utf-8
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/r18n'
require 'couchrest'
require 'nokogiri'
require 'haml'
require 'dalli'
require './topic_model'
require './couchrest_sunspot'
require './server_info'


######################################################################
# @author Steve Anderson                                             #
# Set the routes for dbcom                                           #
######################################################################

# Visit at, for example, http://couch-rest-289.heroku.com/dbcom/en/us/customviews.htm
set :static, true

set :static_cache_control, [:public, :max_age => 36000, :expires => 500]
set :cache, Dalli::Client.new(:expires_in => 500, :compression => true)

# Try to use deflator
use Rack::Deflater

# Views (in the views directory) are defined using haml
# http://haml-lang.com
set :haml, :format => :xhtml

before do
  expires 500, :public, :max_age => 36000
end

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


not_found do
  haml :'404'
end

error do
  haml :'500'
end

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
# get '/*/oocss/*' do | discard, path |
#     set_content_type(path[/(?:.*)(\..*$)/, 1])
#     @thiscss = Topic.by_topicname_and_locale.key(["oocss", "en-us"]).first
#     return @thiscss.read_attachment(path)
# end

# get '/oocss/*' do | path |
#   set_content_type(path[/(?:.*)(\..*$)/, 1])
#   @thiscss = Topic.by_topicname_and_locale.key(["oocss", "en-us"]).first
#   return @thiscss.read_attachment(path)
# end


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

# Search only page
get '/dbcom/:locale/search' do
  # Search only page should go back to the landing page
  haml :search_info
end


# Go to the search page, nothing but the search
get '/dbcom/:locale/search/' do
  haml :search_info
end

# Actual search URL
# @todo Do queries need to be escaped to be safe?
get %r{/(.*)\/(.*)\/search/(.+)} do |root,locale,query|
  @topictitle = t.title.searchresults
  # @sidebartitle = t.title.facets
  # @todo Add the checkboxes here
  # @sidebarcontent = "List of facets, with checkboxes"
  begin
    @search=Sunspot.search(Topic) do
      keywords query do
        highlight :content, :fragment_size => 500, :phrase_highlighter => true, :require_field_match => true, :merge_continuous_fragments => true
      end
      paginate :page => 1, :per_page => 1500
    end
  rescue
    haml :search_no_results, :locals => {:query => query}
  else
    @results = @search.results
    if (@results.length > 0)
    then
      haml :search, :locals => {:locale => locale, :root => root, :query => query}
    else
      haml :search_no_results, :locals => {:query => query}
    end
  end
end

# Grab the search and return a page with the results
post %r{/([^\/]*)\/([^\/]*)\/.*} do |root,locale|
  query = params[:search_query]
  redirect to("#{root}/#{locale}/search/#{query}")
end

# Grab all the relative links that go to images
get %r{/([^\/]*)\/([^\/]*)\/(.*images)\/([^\/]*)} do |root, locale, imagepath, imagename|
  referrer = request.referrer
  topicname = referrer.match(/.*\/([^\/]*)\/([^\/]*)\/(.*)/)[3]
  fullattachmentname = "#{imagepath}/#{imagename}"
  @thistopic = Topic.by_topicname_and_locale.key([topicname, locale]).first
  return @thistopic.read_attachment(fullattachmentname)
end

# Calls to <root>/dbcom/<lang>/<locale>/<topicname> get redirected
# based on the locale key in couchdb
get %r{/([^\/]*)\/([^\/]*)\/([^\/]*)} do |root, locale, topicname|
  puts "WTF?"
  puts "topicname: #{topicname}"
  begin
    @thistopic = Topic.by_topicname_and_locale.key([topicname, locale]).first
    @thisdoc = Nokogiri::XML(@thistopic.read_attachment(topicname))
    @content=@thisdoc.xpath('//body').children().remove_class("body")
    @topictitle=@thisdoc.xpath('//title[1]').inner_text()
    @sidebartitle =t.title.toc
    @sidebarcontent = t.toc
    haml :topic
  rescue
    haml :'500'
  end
end


# Need to support URLs of the format
# http://docs.database.com/dbcom?locale=en-us&target=<filename>&section=<section>
get %r{(.*)} do |root|
  if (
      (defined?(params[:locale])) &&
      (defined?(params[:targetname]))
      (not(params[:locale].nil? || params[:targetname].nil?))
      )
    redirect to("#{root}/#{params[:locale]}/#{params[:target]}")
  else
    haml :'404'
  end
end

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

# Authentication
use Rack::Auth::Basic, "Restricted Area" do |username, password|
  [username, password] == ['devdoc', 'test1234']
end

## Cacching
set :static, true
set :static_cache_control, [:public, :max_age => 36000, :expires => 500]
set :cache, Dalli::Client.new
set :enable_cache, true
set :short_ttl, 400
set :long_ttl, 4600

before do
  expires 500, :public, :must_revalidate
end

# Compress the files
use Rack::Deflater

# Views (in the views directory) are defined using haml
# http://haml-lang.com
set :haml, :format => :xhtml

# Set default root and topic
set :default_root, 'dbcom'
set :default_topic, 'index.htm'

# Add new relic M&M
configure :production do
  require 'newrelic_rpm'
end

# Set up the path to the search index
case
when ENV['WEBSOLR_URL']
  Sunspot.config.solr.url =ENV['WEBSOLR_URL']
when ENV['LOCALSOLR_URL']
  Sunspot.config.solr.url =ENV['LOCALSOLR_URL']
end
STDERR.puts "Indexing with #{Sunspot.config.solr.url}"

# Some R18N magic

# Add t and l helpers
helpers ::R18n::Helpers
# Set default locale and translation dir
set :default_locale, 'en-us'
set :translations, Proc.new { File.join(root, 'i18n/') }

before do
  # Lazy locale setter
  ::R18n.set do
    ::R18n::I18n.default = settings.default_locale
    # Parse browser locales
    locales = ::R18n::I18n.parse_http(request.env['HTTP_ACCEPT_LANGUAGE'])
    locales.insert(0, 'en-us')
    # @todo uncomment when we have ja doc
    # Allow to set locale manually
    # if params[:locale]
    #   if params[:locale].start_with?('ja')
    #     locales.insert(0, 'ja-jp')
    #   else
    #     locales.insert(0, 'en-us')
    #   end
    # elsif session[:locale]
    #   locales.insert(0, session[:locale])
    # end
    # Do your stuff with locales
    ::R18n::I18n.new(locales, settings.translations)
  end
end

# Switch to HTML error for untranslated messages
::R18n::Filters.off(:untranslated)
::R18n::Filters.on(:untranslated_html)


# Sinatra helpers go here
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
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

  # Get the attachment from the cache, or push it into the cache
  def get_attachment(topicname, attachmentname, locale, time_to_live=settings.long_ttl)
    if(!settings.enable_cache)
      then
      @thistopic = Topic.by_topicname_and_locale.key([topicname,locale]).first
      return @thistopic.read_attachment(attachmentname)
    end
    # Check that this is good enough - what about dupe attachment names?
    @key = "#{topicname}/#{attachmentname}"
    if(settings.cache.get(@key) == nil)
      then
      @thistopic = Topic.by_topicname_and_locale.key([topicname,locale]).first
      @image = @thistopic.read_attachment(attachmentname)
      settings.cache.set(@key, @image, ttl=time_to_live+rand(100))
    end
    return settings.cache.get(@key)
  end

  def set_locale(locale)
    # @todo Uncomment the conditional when we have ja-jp doc
    return 'en-us'
    # if locale.start_with?('ja')
    #   return 'ja-jp'
    # else
    #   return 'en-us'
    # end
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
# Ignore the following routes
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

# All calls to help.css should go to the same file
get '*help.css' do
  content_type 'text/css'
  @thiscss = Topic.by_topicname_and_locale.key(["help.css", "en-us"]).first
  return @thiscss.read_attachment("help.css")
end

# All calls to /img should grab it from the app_image_document
get '/img/*' do | path |
  set_content_type(path[/(?:.*)(\..*$)/, 1])
  @image = get_attachment("app_image_document", '/img/'.concat(path), "en-us")
  return @image
end

# User guide PDF
get '/:locale/*.pdf' do |filename|
  @locale = set_locale(params[:locale])
  STDERR.print "Going to #{@locale}/#{filename}.pdf"
end

# Search only page
get '/dbcom/:locale/search' do
  # Search only page should go back to the landing page
  @locale = set_locale(params[:locale])
  haml :search_info
end


# Go to the search page, nothing but the search
get '/dbcom/:locale/search/' do
  @locale = set_locale(params[:locale])
  haml :search_info
end

# Actual search URL
# @todo Do queries need to be escaped to be safe?
get '/:root/:locale/search/:query' do
  root = params[:root]
  locale = set_locale(params[:locale])
  query = params[:query]
  @topictitle = t.title.searchresults
  begin
    @search=Sunspot.search(Topic) do
      keywords query do
        highlight :content, :fragment_size => 500, :phrase_highlighter => true, :require_field_match => true
      end
      with(:locale, locale)
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
  query = h(params[:s])
  locale = set_locale(locale)
  redirect to("#{root}/#{locale}/search/#{query}")
end

# Grab all the relative links that go to images
get %r{/([^\/]*)\/([^\/]*)\/(.*images)\/([^\/]*)} do |root, locale, imagepath, imagename|
  begin
    set_content_type(imagename[/(?:.*)(\..*$)/, 1])
    referrer = request.referrer
    topicname = referrer.match(/.*\/([^\/]*)\/([^\/]*)\/(.*)/)[3]
    fullattachmentname = "#{imagepath}/#{imagename}"
    locale = set_locale(locale)
    @image = get_attachment(topicname, fullattachmentname, locale)
    return @image
  rescue
    return ""
  end
end

# Calls to /dbcom/<locale>/<topicname> get redirected
# based on the locale key in couchdb
get '/:root/:locale/:topicname' do
  topicname = params[:topicname]
  locale = set_locale(params[:locale])
  root = params[:root]
  begin
    @attachment = get_attachment(topicname, topicname, locale)
    @thisdoc = Nokogiri::XML(@attachment)
    @content=@thisdoc.xpath('//body').children().remove_class("body")
    @topictitle=@thisdoc.xpath('//title[1]').inner_text()
    @sidebartitle =t.title.toc
    @sidebarcontent = t.toc
    haml :topic
  rescue
    haml :'404'
  end
end

get '/:locale/:topicname.:format' do
  locale = set_locale(params[:locale])
  redirect to("/#{settings.default_root}/#{locale}/#{params[:topicname]}.#{params[:format]}")
end


get '/:root/:locale/?' do
  locale = set_locale(params[:locale])
  redirect to("/#{params[:root]}/#{locale}/#{settings.default_topic}")
end

get '/:topicname.:format' do
  locale = set_locale(::R18n::I18n.parse_http(request.env['HTTP_ACCEPT_LANGUAGE'])[0])
  redirect to("/#{settings.default_root}/#{locale}/#{params[:topicname]}.#{params[:format]}")
end

# Need to support URLs of the format
# http://docs.database.com/dbcom?locale=en-us&target=<filename>&section=<section>
get %r{(.*)} do |root|
  if (
      (defined?(params[:locale])) &&
      (defined?(params[:target]))
      (not(params[:locale].nil? || params[:target].nil?))
      )
    redirect to("#{root}/#{params[:locale]}/#{params[:target]}")
  else
    locale = set_locale(::R18n::I18n.parse_http(request.env['HTTP_ACCEPT_LANGUAGE'])[0])
#    redirect to("/#{settings.default_root}/#{locale}/#{settings.default_topic}")
    redirect to("http://database.com")
  end
end

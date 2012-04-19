# encoding: utf-8
require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'sinatra/r18n'
require 'couchrest'
require 'nokogiri'
require 'haml'
require 'dalli'
require 'escape_utils'
require 'memcachier'
require './topic_model.rb'
require './couchrest_sunspot.rb'


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
set :haml, :format => :xhtml, :ugly => true

# Set default root and topic
set :default_root, 'dbcom'
set :default_topic, 'dbcom_index.htm'

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
    begin
      STDERR.puts "Get the attachment, trying #{topicname}, #{attachmentname}, #{locale}}"
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
    rescue
      STDERR.puts "Couldn't get the attachment, trying #{topicname}, #{attachmentname}, #{locale}}"
    end
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

  #This is one big case statement that tags the
  # @todo - Figure out where the content comes from (probably an xpath on the attachment) and how to map it.
  def map_tag(tag)
    case
    when tag == "FeatureArea"
      return "Feature Area"
    when tag == "Customization_Setup"
      return "Customization and setup"
    when tag == "Data_Model"
      return "Data model"
    when tag == "Custom_Objects_Tabs_Fields"
      return "Objects and fields"
    when tag == "Validation_Rules"
      return "Validation rules"
    when tag == "Formulas"
      return "Formulas"
    when tag == "Data_Management"
      return "Data management"
    when tag == "Data_Loader"
      return "Data Loader"
    when tag == "Data_Export"
      return "Data export"
    when tag == "Logic"
      return "Logic"
    when tag == "Apex_Code_Development_Deployment"
      return "Apex Code"
    when tag == "Workflow_Approvals"
      return "Workflow"
    when tag == "API_Integration_Performance"
      return "Integration"
    when tag == "Bulk_API"
      return "Bulk API"
    when tag == "Chatter_REST_API"
      return "Chatter REST API"
    when tag == "Java_SDK"
      return "Java SDK"
    when tag == "Metadata_API"
      return "Metadata API"
    when tag == "REST_Metadata_API"
      return "Metadata REST API"
    when tag == "REST_API"
      return "REST API"
    when tag == "SOAP_API"
      return "SOAP API"
    when tag == "Streaming_API"
      return "Streaming API"
    when tag == "Security"
      return "Security"
    when tag == "Passwords_Login"
      return "Passwords"
    when tag == "OAuth"
      return "OAuth"
    when tag == "Sharing_Visibility"
      return "Sharing and visibility"
    when tag == "Manage_Users_Profiles"
      return "Users and profiles"
    when tag == "Deployment_Distribution"
      return "Testing and deployment"
    when tag == "Change_Management_Change_Sets"
      return "Change sets"
    when tag == "Deploying"
      return "Deploying"
    when tag == "Sandbox"
      return "Test databases"
    when tag == "Packaging_for_Distribution"
      return "Packaging for distribution"
    when tag == "Mobile"
      return "Mobile development"
    when tag == "Type"
      return "Type"
    when tag == "FAQ"
      return "FAQs"
    when tag == "Guide"
      return "Guides"
    when tag == "RelNote"
      return "Release notes"
    when tag == "Tutorial"
      return "Tutorials"
    when tag == "Video"
      return "Videos"
    else
      return ''
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
# get '/dbcom/:locale/:pdfname.pdf' do
#    @locale = set_locale(params[:locale])
# end

# Top level page
get '/dbcom/:locale/dbcom_index.htm' do
  STDERR.puts "In the top-level page"
  # Search only page should go back to the landing page
  @locale = set_locale(params[:locale])
  haml :landing
end


# Go to the search page, nothing but the search
get '/dbcom/:locale/search/' do
  STDERR.puts "In the search/"
  @locale = set_locale(params[:locale])
  haml :search_info
end

get '/dbcom/:locale/search' do
    STDERR.puts "In the search"
  @locale = set_locale(params[:locale])
  haml :search_info
end


# Actual search URL, with a facet
get '/:root/:locale/search/facet' do
  STDERR.puts "In the faceted search, with no query"
  root = params[:root]
  locale = set_locale(params[:locale])
  app_area = params[:app_area].length > 0 ? params[:app_area].split : []
  type = params[:type].length > 0 ? params[:type].split : []
  @topictitle = t.title.searchresults
  @fullURL = request.url
  @baseURL = @fullURL.match(/(.*)\/search\/.*/)[1]
  if (@baseURL.include? 'search')
    @baseURL.sub!(/\/search/,'')
  end
  begin
    @search=Sunspot.search(Topic) do
      with(:locale, locale)
      with(:app_area,app_area) if app_area.length > 0
      with(:doctype).any_of(type) if type.length > 0
      paginate :page => 1, :per_page => 1500
    end
  rescue
    haml :search, :locals => {:locale => locale, :root => root, :query => '', :app_area => app_area, :type => type }
  else
    @results = @search.results
    if (@results.length > 0)
    then
      haml :search, :locals => {:locale => locale, :root => root, :query => '', :app_area => app_area, :type => type }
    else
      haml :search, :locals => {:locale => locale, :root => root, :query => '', :app_area => app_area, :type => type }
    end
  end
end


# Actual search URL, with a facet
get '/:root/:locale/search/:query/facet' do
  STDERR.puts "In the faceted search"
  root = params[:root]
  locale = set_locale(params[:locale])
  query = params[:query]
  app_area = params[:app_area].length > 0 ? params[:app_area].split : []
  type = params[:type].length > 0 ? params[:type].split : []
  @topictitle = t.title.searchresults
  @fullURL = request.url
  @baseURL = @fullURL.match(/(.*)\/search\/.*/)[1]
  if (@baseURL.include? 'search')
    @baseURL.sub!(/\/search/,'')
  end
  begin
    @search=Sunspot.search(Topic) do
      keywords query do
        highlight :content, :fragment_size => 500, :phrase_highlighter => true, :require_field_match => true
      end
      with(:locale, locale)
      with(:app_area,app_area) if app_area.length > 0
      with(:doctype).any_of(type) if type.length > 0
      paginate :page => 1, :per_page => 1500
    end
  rescue
    haml :search, :locals => {:locale => locale, :root => root, :query => query, :app_area => app_area, :type => type }
  else
    @results = @search.results
    if (@results.length > 0)
    then
      haml :search, :locals => {:locale => locale, :root => root, :query => query, :app_area => app_area, :type => type }
    else
      haml :search, :locals => {:locale => locale, :root => root, :query => query, :app_area => app_area, :type => type }
    end
  end
end

# Actual search URL
# @todo Do queries need to be escaped to be safe?
get '/:root/:locale/search/:query' do
  root = params[:root]
  locale = set_locale(params[:locale])
  query = params[:query]
  app_area = []
  type = []
  @topictitle = t.title.searchresults
  @fullURL = request.url
  @baseURL = @fullURL.match(/(.*)\/search\/.*/)[1]
  STDERR.puts "In the search with a query"
  begin
    @search=Sunspot.search(Topic) do
      keywords query do
        highlight :content, :fragment_size => 250, :phrase_highlighter => true, :require_field_match => true
      end
      with(:locale, locale)
      paginate :page => 1, :per_page => 1500
    end
  rescue
    STDERR.puts "Getting rescued in the search"
    haml :search, :locals => {:locale => locale, :root => root, :query => query, :app_area => app_area, :type => type }
  else
    @results = @search.results
    if (@results.length > 0)
    then
      haml :search, :locals => {:locale => locale, :root => root, :query => query, :app_area => app_area, :type => type }
      # haml :search, :locals => {:locale => locale, :root => root, :query => query}
    else
      haml :search, :locals => {:locale => locale, :root => root, :query => query, :app_area => app_area, :type => type }
    end
  end
end

# Grab the search and return a page with the results
post %r{/([^\/]*)\/([^\/]*)\/.*} do |root,locale|
  locale = set_locale(locale)
  query = params[:s]
  query.sub!(/\%/, '%25')
  STDERR.puts "Am I in a post?  what is my query? #{query}"
  redirect to("#{root}/#{locale}/search/#{query}")
end


# Grab all the relative links that go to images
get %r{/([^\/]*)\/([^\/]*)\/([^\/]*)\/(.*images)\/([^\/]*)} do |root, locale, deliverable,imagepath, imagename|
  STDERR.puts "In the image root"
  begin
    set_content_type(imagename[/(?:.*)(\..*$)/, 1])
    referrer = request.referrer
    filename = referrer.match(/.*\/([^\/]*)\/([^\/]*)\/([^\/]*)\/(.*)/)[4]
    topicname = "#{deliverable}/#{filename}"
    fullattachmentname = "#{imagepath}/#{imagename}"
    locale = set_locale(locale)
    @image = get_attachment(topicname, fullattachmentname, locale)
    return @image
  rescue
    return ""
  end
end

# Get a JSON file
get '/:root/:locale/:guide/:topicname.json' do
  STDERR.puts "In the json route"
  topicname = params[:guide] + "/" + params[:topicname] + ".json"
  locale = set_locale(params[:locale])
  root = params[:root]
    begin
      @this_json = get_attachment(topicname, topicname, locale)
      return @this_json
    rescue
      haml :'404'
    end
end

# Broken - fix it!
get '/dbcom/en-us/db_help/dbcom_help_dbcom_user_guide.htm' do
  STDERR.puts "In the broken redirect"
  redirect to("/dbcom/en-us/db_help/index.htm")
end

get '/:root/:locale/:guide/:topicname' do
  STDERR.puts "In the topicname"
  topicname = params[:guide] + "/" + params[:topicname]
  locale = set_locale(params[:locale])
  root = params[:root]
    begin
      @locale = params[:locale]
      @topickey = params[:topicname]
      @guide = params[:guide]
      @attachment = get_attachment(topicname, topicname, locale)
      @thisdoc = Nokogiri::XML(@attachment)
      @toc_json = @thisdoc.xpath("//meta[@name = 'SFDC.TOC']/@content")
      @toc_json_URL = params[:guide] + "/" + @toc_json.to_s
      @content=@thisdoc.xpath('//body').children()
      @topictitle=@thisdoc.xpath('//title[1]').inner_text()
      @sidebartitle=@thisdoc.xpath("//meta[@name = 'SFDC.Title']/@content")
      @relatedpdf=@thisdoc.xpath("//meta[@name = 'SFDC.RelatedPDF']/@content")
      @appareas=@thisdoc.xpath("//meta[@name = 'app_area']/@content").to_s.strip.split
      @sidebarcontent = t.toc
      @fullURL = request.url
      @baseURL= "#{@fullURL.match(/(.*)\/#{topicname}/)[1]}"
      @toc_json_fullURL = "#{@baseURL}/#{@toc_json_URL}"
      @app_keys_and_labels = Hash[@appareas.map{|category|[category, map_tag(category)]}].select{|k,v| v.length > 0} unless @appareas.nil?
      haml :topic, :locals => { :topicname => topicname}
  rescue
      STDERR.puts "I've been rescued from a topic call, this results in a 404 error."
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
    STDERR.puts "In the root:format"
  locale = set_locale(::R18n::I18n.parse_http(request.env['HTTP_ACCEPT_LANGUAGE'])[0])
  redirect to("/#{settings.default_root}/#{locale}/#{params[:topicname]}.#{params[:format]}")
end

# Need to support URLs of the format
# http://docs.database.com/dbcom?locale=en-us&target=<filename>&section=<section>
# http://docs.database.com/dbcom?locale=en-us&target=index.htm&section=foo
get %r{(.*)} do |root|
  STDERR.puts "In the context sensitive help route"
  if (
      (defined?(params[:locale])) &&
      (defined?(params[:target]))
      (not(params[:locale].nil? || params[:target].nil?))
      )
    redirect to("#{root}/#{params[:locale]}/db_help/#{params[:target]}")
  else
    locale = set_locale(::R18n::I18n.parse_http(request.env['HTTP_ACCEPT_LANGUAGE'])[0])
    @fullURL = request.url
    STDERR.puts "full URL -> #{@fullURL}"
    redirect to("/#{settings.default_root}/#{locale}/#{settings.default_topic}")
  end
end

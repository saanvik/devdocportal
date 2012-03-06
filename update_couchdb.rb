require 'rubygems'
require 'bundler/setup'
require 'sinatra'
require 'couchrest'
require 'couchrest_model'
require 'nokogiri'
require 'css_parser'
require './globals.rb'
require './topic_model.rb'
#include CSSParser

case
when ENV['WEBSOLR_URL']
  Sunspot.config.solr.url =ENV['WEBSOLR_URL']
when ENV['LOCALSOLR_URL']
  Sunspot.config.solr.url =ENV['LOCALSOLR_URL']
else
  STDERR.puts "No search engine URL defined."
  exit(2)
end
puts "Indexing in the update with with #{Sunspot.config.solr.url}"

# Sets the items that will be added to the search index.
Sunspot.setup(Topic) do
  text :content, :stored => true
  text :perm_and_edition_tables, :stored => false
  text :title, :stored => true
  string :app_area, :stored => true, :multiple => true do
    app_area.split
  end
  string :edition, :stored => true, :multiple => true do
    edition.split
  end
  string :identifier, :stored => true
  string :locale, :stored => true
  string :product, :stored => true , :multiple => true do
    product.split
  end
  string :role, :stored => true , :multiple => true do
    role.split
  end
  string :topicname, :stored => true
  time :updated_at, :stored => true
  integer :api_version_removed, :stored => true
  string :version_removed, :stored => true
end

######################################################################
# This code pushes topics (output from help build), and collateral,  #
# like CSS and images, into couchdb                                  #
#                                                                    #
# @author Steven Anderson                                            #
# This code depends on data defined in the globals file              #
######################################################################

# Lookup the mime type using Rack
# @param [String] extension the extension of the file, including the period, `.css` or `.html`.
# @return [String] the mime type.
def get_mime_type(extension)
  begin
    return Rack::Mime.mime_type(extension)
  rescue
    STDERR.puts "Couldn't find the MIME type for #{extension}."
  end
end

# Lookup the mime type using Rack
# @param [String] documentname The couchdb documentname
# @param [String] locale The locale, in the form of lang-locale, for the attachment.
# @param [String] fullpath The path, in the OS, to the file that is being added as an attachment
# @param [String] mime_type The mime type of the attachment.
# @param [String] attachmentname Used as a key for lookups.
def upload_attachment(documentname,locale,fullpath, mime_type,attachmentname)
  thisfile = File.new("#{fullpath}")
  # Create the hash of the file for comparison, since we don't want to update the attachment if it hasn't changed
  this_attachment_hash = Digest::SHA256.file(thisfile).hexdigest
  dupe = Topic.by_topicname_and_locale.key(["#{documentname}","#{locale}"]).count > 0
  unless dupe
  then
    begin
      @thisattachment = Topic.create({
                                    :locale => locale,
                                    :attachment_hash => this_attachment_hash,
                                    :topicname => documentname})
      @thisattachment.create_attachment(
                                          :name => attachmentname,
                                          :file => thisfile,
                                          :content_type => mime_type)
    rescue
      STDERR.puts "Could not create a new topic with lang/locale: #{locale} and filename #{documentname}"
    end
  else
    # Hopefully we don't need the first, but just in case
    @thisattachment = Topic.by_topicname_and_locale.key(["#{documentname}","#{locale}"]).first
    begin
      @thisattachment.update_attributes(
                                        :version_removed => CURRENT_PATCH,
                                        :api_version_removed => CURRENT_API_VERSION,
                                        :locale => locale,
                                        :topicname => documentname)
    rescue
      STDERR.puts "Could not update attributes on lang/locale: #{locale} and filename #{documentname}"
    end
    # If there is already an attachment with this filename, check to see if it needs to be updated
    if (@thisattachment.has_attachment?(attachmentname))
    then
      # Only update it if it's changed
      couch_attachment_hash = Digest::SHA256.hexdigest(@thisattachment.read_attachment(attachmentname))
      if (couch_attachment_hash != this_attachment_hash)
      then
        begin
          @thisattachment.update_attributes({:attachment_hash => this_attachment_hash})
          @thisattachment.update_attachment({
                                              :name => attachmentname,
                                              :file => thisfile,
                                              :content_type => mime_type})
        rescue
    STDERR.puts "Could not update attributes, or the attachment on lang/locale: #{locale} and filename #{documentname}, for #{attachmentname}"
        end
      end
      else
        begin
          @thisattachment.update_attributes({:attachment_hash => this_attachment_hash})
          @thisattachment.create_attachment({
                                              :name => attachmentname,
                                              :file => thisfile,
                                              :content_type => mime_type})
        rescue
          STDERR.puts "Could not update attributes on lang/locale: #{locale} and filename #{documentname}"
        end
    end
  end
  begin
    # This may not be required, but the couchrest::model doc isn't clear if create_attachment saves the document or not.
    @thisattachment.save
  rescue
    STDERR.puts "Could not save filename #{documentname}"
  end
  thisfile.close
end

# Update the metadata for the attachment.  Most of the metadata is
# stored in the XML files.  If your XML doesn't have this metadata, or
# it has other metadata, change this method, and change the model
# definition.
# @param [String] filename The name of the file, with the extension.
# @param [String] fullpath The path, in the OS, to the file that is
# being added as an attachment
# @param [String] mime_type The mime type of the attachment.
# @param nokodoc The nokogiri representation of the HTML document.
# @param [String] locale The locale of the attachment.
def update_metadata_from_attachment(filename,fullpath, mime_type, nokodoc,locale)
  thisfile = File.new("#{fullpath}")
  app_area = nokodoc.xpath("//meta[@name = 'app_area']/@content")
  product = nokodoc.xpath("//meta[@name = 'product']/@content")
  role = nokodoc.xpath("//meta[@name = 'role']/@content")
  edition = nokodoc.xpath("//meta[@name = 'edition']/@content")
  topic_type = nokodoc.xpath("//meta[@name = 'product']/@content")
  identifier = nokodoc.xpath("//meta[@name = 'DC.Identifier']/@content")
  upload_attachment(filename,locale,fullpath, mime_type,filename)
  perm_and_edition_tables=nokodoc.xpath('//table[contains(@class, "permTable") or contains(@class, "editionTable")]').inner_text()
  body_content=nokodoc.xpath('//body')
  # Remove items we don't want returned in the search snippet
  body_content.xpath('//table[contains(@class, "permTable") or contains(@class, "editionTable")]').remove
  body_content.xpath('//h1[1]').remove
  body_content.xpath('//*[contains(@class, "breadcrumbs")]').remove
  content=body_content.children().inner_text()
  title=nokodoc.xpath('//title[1]').inner_text()

  @thistopic = Topic.by_topicname_and_locale.key(["#{filename}","#{locale}"]).first
  begin
    # If @thistopic doesn't exist, it will be a NilClass, which
    # doesn't have the update_attributes method.  We need to catch
    # that.
    @thistopic.update_attributes(
                                 :version_removed => CURRENT_PATCH,
                                 :api_version_removed => CURRENT_API_VERSION,
                                 :locale => locale,
                                 :topicname => filename,
                                 :app_area => app_area,
                                 :product => product,
                                 :role => role,
                                 :edition => edition,
                                 :topic_type => topic_type,
                                 :identifier => identifier,
                                 :content => content,
                                 :perm_and_edition_tables => perm_and_edition_tables,
                                 :title => title)
  rescue NoMethodError
    STDERR.puts "Error: Could not update the attributes on #{filename}.  Check the couchdb connection."
    STDERR.puts "#{$!}"
  rescue RestClient::RequestFailed => e
    STDERR.puts "Error: Could not update the attributes on #{filename}."
    if (e.http_code == 409 or e.http_code == 412)
      then
      STDERR.puts "The problem was caused by a conflict or a precondition issue.  Trying again."
      @thistopic.reload
      begin
        @thistopic.update_attributes(
                                     :version_removed => CURRENT_PATCH,
                                     :api_version_removed => CURRENT_API_VERSION,
                                     :locale => locale,
                                     :topicname => filename,
                                     :app_area => app_area,
                                     :product => product,
                                     :role => role,
                                     :edition => edition,
                                     :topic_type => topic_type,
                                     :identifier => identifier,
                                     :content => content,
                                     :perm_and_edition_tables => perm_and_edition_tables,
                                     :title => title)
        STDERR.puts "Success!"
      rescue
        STDERR.puts "Nope.  Updating the attributes on #{filename} still failed."
      # Now add it to the SOLR search index.
      else
        begin
          index_topic_with_solr(@thistopic)
        rescue
          STDERR.puts "Couldn't add #{filename} to the SOLR index"
        end
      end
    else
      STDERR.puts "There was an error (#{e.http_code}) updating #{filename}."
    end
  rescue
    STDERR.puts "Error: Could not update the attributes on #{filename}."
    STDERR.puts "#{$!}"
    raise
  else
    # Now add it to the SOLR search index.
    begin
      index_topic_with_solr(@thistopic)
    rescue
      STDERR.puts "Couldn't add #{filename} to the SOLR index"
    end
  end
  thisfile.close
end

# Upload the images referenced in the HTML attachment.
# @param [String] filename The name of the file, with the extension.
# being added as an attachment
# @param [String] mime_type The mime type of the attachment.
# @param nokodoc The nokogiri representation of the HTML document.
# @param [String] locale The locale of the attachment.
# Case 1 - path does not start with a / - attach it to this document
# Case 2 - path does start with / - attach it to app_image_document
# Else is there just in case
# Since the file may not be available, we need to catch any exceptions
def upload_referenced_images(filename, mime_type, nokodoc, locale)
  nokodoc.xpath("//img/@src").each do |image|
    begin
      @original_filename = filename
      case
      when (image.text =~ /^[^\/].*/)
        fullpath = "#{DOCSRCDIR}#{image.text}"
        begin
          mime_type = get_mime_type(fullpath[/(?:.*)(\..*$)/, 1])
        rescue
          @mime_type = ""
        end
        begin
          if File.exist?(fullpath)
          then
            upload_attachment(filename,locale,fullpath,mime_type,image.text)
          else
            STDERR.puts "Failed to find the file\n\t #{fullpath}\n referenced by \n\t #{@original_filename}"
          end
        rescue
          STDERR.puts "Failed to upload file\n\t #{fullpath}\n referenced by \n\t #{@original_filename}"
        end
      when (image.text =~ /^[\/].*/)
        fullpath = "#{APPSRCDIR}#{image.text}"
        begin
          mime_type = get_mime_type(fullpath[/(?:.*)(\..*$)/, 1])
        rescue
          @mime_type = ""
        end
        begin
          if File.exist?(fullpath)
          then
            upload_attachment('app_image_document',locale,fullpath,mime_type,image.text)
          else
            STDERR.puts "Failed to find the file\n\t #{fullpath}\n referenced by \n\t #{@original_filename}"
          end
        rescue
          STDERR.puts "Failed to upload linked file\n\t #{fullpath}\n referenced by \n\t #{@original_filename}"
        end
      else
          STDERR.puts "Failed to upload file\n\t #{fullpath}\n referenced by \n\t #{@original_filename}"
      end
    rescue
      STDERR.puts "File\n\t #{image.text}\n referenced by \n\t #{@original_filename} is not formatted in a way I understand."
    end
  end
end

def index_topic_with_solr(thistopic)
    Sunspot.index(thistopic)
    Sunspot.commit
end

# Upload all the HTML, CSS, and JavaScript files to couchdb.
# Images are uploaded by reference only.
# Uploading HTML files also adds them to the index and updates refereneced image files.
# Start by changing to the correct output directory
Dir.chdir "#{DOCSRCDIR}"
Dir.glob("**/*.{html,htm,css,js}") do |filename|
  fullpath = "#{DOCSRCDIR}#{filename}"
  begin
    mime_type = get_mime_type(fullpath[/(?:.*)(\..*$)/, 1])
  rescue
    @mime_type = ""
  end
  case
  when mime_type =~ /html/
    # HTML files are special.  We create a document and attach the HTML file.
    nokodoc = Nokogiri::XML(open("#{fullpath}"))
    locale=nokodoc.xpath('/html/@lang')
    update_metadata_from_attachment(filename,fullpath, mime_type,nokodoc,locale)
    upload_referenced_images(filename, mime_type,nokodoc,locale)
  else
    upload_attachment(filename,LOCALE,fullpath, mime_type,filename)
  end
end

# We're using CSS files stored in a different location, so we need to upload them separately.
# Change to the CSS directory
# @todo - now we're using the CSS file in public/oocss
Dir.chdir "#{CSSDIR}"
Dir.glob("**/*.{css,js}") do |filename|
  fullpath = "#{CSSDIR}#{filename}"
  begin
    mime_type = get_mime_type(fullpath[/(?:.*)(\..*$)/, 1])
  rescue
    @mime_type = ""
  end
  # Special case for oocss files
  # Since they depend on relative paths, we need to keep them all in the same document.
  upload_attachment('oocss',LOCALE,fullpath,mime_type,filename)
  if mime_type =~ /css/
    then
    parser = CssParser::Parser.new
    parser.load_uri!(fullpath)
    parser.each_selector(:all) do |selector,declarations,specificity|
      if (declarations.include? 'url("/')
        @img_path = /url\(.(\/[^'#")]*)/.match(declarations)
        @img_fullpath = "#{APPSRCDIR}#{@img_path[1]}"
        if File.exist?(@img_fullpath)
        then
          begin
            @mime_type = get_mime_type(@img_fullpath[/(?:.*)(\..*$)/, 1])
          rescue
            @mime_type = ""
          end
          begin
            upload_attachment('app_image_document',LOCALE,@img_fullpath,@mime_type,@img_path[1])
          rescue
          STDERR.puts "Failed to upload file\n\t #{@img_fullpath}\n referenced by \n\t #{filename} with #{@mime_tpe}"
          end
        else
          STDERR.puts "Missing file\n#{@img_fullpath}\n referenced by \n\t #{filename}."
        end
      end
    end
  end
end

# Upload "extra" images
Dir.chdir "#{IMGDIR}"
Dir.glob("**/*.*") do |filename|
  fullpath = "#{IMGDIR}#{filename}"
  begin
    mime_type = get_mime_type(fullpath[/(?:.*)(\..*$)/, 1])
  rescue
    @mime_type = ""
  end
  # Special case for "extra" images
  begin
    upload_attachment('app_image_document',LOCALE,fullpath,@mime_type,"/img/#{filename}")
  rescue
    STDERR.puts "Failed to upload file\n\t #{fullpath}\n"
  end
end




# We don't need to start Sinatra, so close the app
exit(0)

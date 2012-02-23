# @author Steve Anderson
# Globals for developer doc portal
#
## @todo: Allow these to be overridden at the command line

WD = Dir.getwd

# Assumption -
# if you are Windows, you're working in c:\dev\doc\...
# if you are not, you're working in ~/dev/doc

HOMEDIR = RUBY_PLATFORM.downcase.include?("mswin")? ENV['HOMEDRIVE'] : ENV['HOME']

# Set the current API version.
CURRENT_API_VERSION ||= 24

# Set the current patch number
CURRENT_PATCH ||= 178.0

# Source of the content - must end with a /
DOCSRCDIR ||= "#{WD}/help_build/en/"

# APPSRCDIR is for images in the form of /img
APPSRCDIR ||= "#{HOMEDIR}/dev/app/main/core/sfdc/htdocs"

# Source of the app images
APPIMGSRC ||= "#{HOMEDIR}/dev/app/main/core/sfdc/htdocs/img"

# Default lang/locale
LOCALE ||= "en-us"

# Release name
RELNAME ||= "spring12"

# Location of the oocss files
CSSDIR ||= "#{WD}/public/oocss/"

# Source of the "extra" images
IMGDIR ||= "#{CSSDIR}/images/"


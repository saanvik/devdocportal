# @author Steve Anderson
# Globals for developer doc portal
#
## @todo: Allow these to be overridden at the command line

# Set the current API version.
CURRENT_API_VERSION ||= 23

# Set the current patch number
CURRENT_PATCH ||= 174.10

# Source of the content
DOCSRCDIR ||= "/Users/sanderson/dev/doc/main/core/devdocportal_out/"

# APPSRCDIR is for images in the form of /img
APPSRCDIR ||= "/Users/sanderson/dev/app/main/core/sfdc/htdocs"

# Source of the app images
APPIMGSRC ||= "/Users/sanderson/dev/app/main/core/sfdc/htdocs/img"

# Default lang/locale
LOCALE ||= "en-us"

# Release name
RELNAME ||= "winter12"

# Indextank index name
INDEXNAME ||= "#{RELNAME}_#{LOCALE}_index"

# Location of the oocss files
CSSDIR ||= "/Users/sanderson/lang/ruby/devdocportal/public/oocss/"

# Source of the "extra" images
IMGDIR ||= "#{CSSDIR}/images/"


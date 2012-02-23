# @author Steve Anderson
# Globals for developer doc portal
#
## @todo: Allow these to be overridden at the command line

# Set the current API version.
CURRENT_API_VERSION ||= 24

# Set the current patch number
CURRENT_PATCH ||= 178.0

# Source of the content - must end with a /
DOCSRCDIR ||= "/Users/sanderson/dev/doc/main/feature/devdocportal/178/help_build/en/"

# APPSRCDIR is for images in the form of /img
APPSRCDIR ||= "/Users/sanderson/dev/app/main/core/sfdc/htdocs"

# Source of the app images
APPIMGSRC ||= "/Users/sanderson/dev/app/main/core/sfdc/htdocs/img"

# Default lang/locale
LOCALE ||= "en-us"

# Release name
RELNAME ||= "spring12"

# Location of the oocss files
CSSDIR ||= "/Users/sanderson/dev/doc/main/feature/devdocportal/178/public/oocss/"

# Source of the "extra" images
IMGDIR ||= "#{CSSDIR}/images/"


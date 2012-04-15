Developer Doc Portal
=============

This is the 178 working version of the developer documentation
portal, a heroku based application for delivering content to
salesforce, force.com, and database.com developers.

[See it live](http://devdocportal-178.herokuapp.com/dbcom/en-us/dbcom_index.htm) 

Username: devdoc
Password: test1234

Requirements
------------

* Ruby 1.9.2
** Use "bundle install" to install the required gems
* Couchdb
* Solr
* memcached

Process
------
* Update globals.rb as required
* Run rake update\_local\_db
* Run rake start\_local\_with\_foreman
* Open your web browser to http://localhost:5000

* To upload to heroku, use rake update\_remote\_db

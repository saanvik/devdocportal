require 'rubygems'
require 'bundler/setup'

task :init_local do
  LOCALDB = ENV['LOCALCOUCH_URL'] = "http://admin:admin@localhost:5984/spring12"
  LOCALSOLR = ENV['LOCALSOLR_URL'] = "http://127.0.0.1:8990/solr"
end

task :update_local_db => [:init_local]do
  sh %{ruby update_couchdb.rb}
end

task :start_local => [:init_local]do
  sh %{ruby start_portal.rb}
end

task :start_local_with_bundle => [:init_local]do
  sh %{bundle exec thin -R config.ru start}
end

task :start_local_with_foreman => [:init_local]do
  sh %{foreman start}
end

task :start_local_with_shotgun => [:init_local]do
  sh %{shotgun thin -p 5000 -E development}
end

task :start_local_with_remote => [:init_remote]do
  sh %{ruby start_portal.rb}
end


task :init_remote do
  REMOTEDB = ENV['CLOUDANT_URL'] = "https://app2997731.heroku:f0Se6BoDD5dHWua1pjyakMHC@app2997731.heroku.cloudant.com"
  REMOTESOLR = ENV['WEBSOLR_URL'] = "http://index.websolr.com/solr/c85264153fb"
end

task :update_remote_db => [:init_remote]do
 sh %{ruby update_couchdb.rb}
end

task :test_local_portal => [:init_local]do
     sh %{ruby test_portal.rb}
end

require 'rubygems'
require 'bundler/setup'
require 'sunspot'
require 'couchrest'
require 'couchrest_model'
require 'sunspot/rails'

module Sunspot
  module Couch
    def self.included(base)
      base.class_eval do
        extend Sunspot::Rails::Searchable::ActsAsMethods
        Sunspot::Adapters::DataAccessor.register(DataAccessor, base)
        Sunspot::Adapters::InstanceAdapter.register(InstanceAdapter, base)
      end
    end

    class InstanceAdapter < Sunspot::Adapters::InstanceAdapter
      def id
        @instance.id
      end
    end

    class DataAccessor < Sunspot::Adapters::DataAccessor
      def load(id)
        Topic.get(id)
      end

      def load_all(ids)
        ids.map {| id | Topic.get(id)}
      end
    end
  end
end

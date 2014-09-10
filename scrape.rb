#!/usr/bin/env rbx
#
# Scrapes 
#

CONFIG_FILE        = './config.yml'
MONGO_SEARCH_DELAY = 10

require_relative './lib/monitor.rb'
require_relative './lib/retriever.rb'
require 'yaml'
require 'mongo'
require 'logger'
include Mongo

# Load config file
conf = YAML::load(File.read(CONFIG_FILE))


# Set up log.
# TODO: this should be configurable
log = Logger.new(STDOUT)
log.level = Logger::INFO


# Connect to mongo.
mongo = MongoClient.new(conf[:mongo][:host], conf[:mongo][:port])
db    = mongo.db(conf[:mongo][:database])
db.authenticate(conf[:mongo][:username], conf[:mongo][:password]) if conf[:auth]

# `create' the index table and ensure it's fast enough for random access stuff.
index = db.collection(conf[:collections][:index])



# Fire up a thread to handle downloads
event_watcher = GameMonitor.new(conf[:announce_url], index, conf[:retry_delay], log)
event_watcher.listen


# An object to retrieve event streams
stream_retriever = GameRetriever.new(conf[:event_url], db, log)

# TODO: pump mongodb for things that aren't yet finished: true, and download the
#       contents to a new collection for each.
begin

  loop{

    # Select from mongoDB where the retrieved: false property
    # is set
    while(record = index.find_one({retrieved: false}))

      # Convert from BSON
      record = record.to_h
      hash = record['hash']

      # Delete it if it doesn't have a hash
      unless hash
        index.remove(record['_id'])
        next
      end

      # Else retrieve the event stream
      stream_retriever.retrieve(hash)
      # puts "=--> #{record}"

      # Save record back to mongo
      record['retrieved'] = true
      index.save(record)

      # And wait...
      log.info "Waiting #{conf[:event_download_delay]}s until next download..."
      sleep(conf[:event_download_delay].to_f)
    end

    # Wait so we don't hit mongo too hard
    sleep(MONGO_SEARCH_DELAY)

  }


rescue StandardError => se

end


# Wait for the thing to stop
event_watcher.stop
event_watcher.thread.join

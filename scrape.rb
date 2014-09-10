#!/usr/bin/env rbx
#
# Scrapes 
#

CONFIG_FILE = './config.yml'

require_relative './lib/monitor.rb'
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


# TODO: pump mongodb for things that aren't yet finished: true, and download the
#       contents to a new collection for each.
sleep


# Wait for the thing to stop
event_watcher.stop
event_watcher.thread.join

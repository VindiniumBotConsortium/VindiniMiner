#!/usr/bin/env rbx
#
# Scrapes 
#

CONFIG_FILE = './config.yml'


require 'yaml'
require 'blat'


# Load config file
conf = YAML.load(File.read(CONFIG_FILE))


# TODO:
#
#  * Connect to local mongo instance
#  * Spawn a thread that connects to the long-poll end on vindinium and:
#    - If a new ID is seen, add it to the index table and start a thread consuming its
#      event stream
#



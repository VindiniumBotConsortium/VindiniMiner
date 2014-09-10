VindiniMiner
============

Mines vindinium for current games, and records the event streams to a mongoDB.

Requirements
============

Currently there's a gemfile but it's completely ignored.  TODO.

 * Rubinius - True multi-threaded listening stuff is needed
 * curb - For downloading stuff
 * mongo - For storing stuff

Instructions
============

 1. Install mongodb
 2. Install Rubinius and the various gems (rubinius allows it to multithread properly)
 3. Configure stuff using the YAML file
 4. run ./scrape.rb

Architecture
============
The system runs using a producer/consumer model, using MongoDB as the RPC system.  One thread continually polls the endpoint which announces new games, writing entries to the mongodb index with 'retrieved: false' in their body.  Another process then polls mongoDB to download these endpoints.

This could get messy when mongo gets full and starts to slow down.  Probably nothing to worry about yet though.  Might be worth ensuring indices exist on the 'retrieved' key.

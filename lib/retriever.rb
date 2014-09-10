

class GameRetriever


  require 'json'
  require 'mongo'
  require 'logger'
  require 'net/http'

  DATA_LINE_RX = /^data:\s*(?<event>\{.*?)\s+$/

  def initialize(base_url, db, index, log=Logger.new(STDOUT))
    @base_url = base_url
    @base_url = "#{base_url}/" unless @base_url.to_s =~ /\/$/ # Ensure it ends with a slash
    @db       = db
    @index    = index
    @log      = log

    puts "\n\n ==> #{db} // #{index} // #{base_url}"
  end

  def retrieve(hash)
    @log.info "Retrieving game: #{hash}"

    # This should be joined with a proper URI object,
    # but the task is simple so...
    url = "#{@base_url}#{hash}"

    # Super-simple get
    body = Net::HTTP.get(URI(url))

    # Parse
    collection = @db.collection(hash)
    parse_event_stream(body, collection)

    # Update the index for the item we have done stuff to.
    @index.find_and_modify(query:  {hash: hash}, 
                           update: {retrieved: true})

  rescue StandardError => se
    @log.error "Failure downloading events: #{se}\n#{se.backtrace.join("\n")}"
  end

  private

  # Parse a raw event stream into a series
  # of JSON objects
  def parse_event_stream(str, collection)
    count = 0

    str.each_line do |line|

      # See if it's sane
      next unless(m = line.match(DATA_LINE_RX))
      event = m[:event]

      begin
        record = JSON.parse(event)
        next unless record.is_a?(Hash)
        # insert
        collection.save(record)
        count += 1
      rescue JSON::ParserError
        # We don't care.
      end
    end

    @log.info "Read #{count} events into collection '#{collection.name}'"
  rescue StandardError => se
    @log.error "Failed to parse event stream.  Dropping collection '#{collection.name}' to ensure consistency."
    @db.drop_collection(collection.name)
  end


end




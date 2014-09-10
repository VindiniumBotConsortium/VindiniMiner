

# Watches the current game announcements on vindinium
class GameMonitor


  require 'curl'
  require 'json'
  require 'mongo'
  require 'logger'

  attr_reader :thread, :url, :index, :delay, :stop

  DATA_LINE_RX = /^data:\s*(?<list>\[.*?\])/

  def initialize(url, index, delay = 10, log = Logger.new(STDOUT))
    @url    = url
    @index  = index
    @delay  = delay
    @log    = log

    # Configure mongo & thread handling
    @index.ensure_index({:hash => 1}, {unique: true, sparse: true, dropDups: true})
    Thread.abort_on_exception = true

    # Set to true to stop next time the
    # request times out
    @stop       = false
    @thread     = nil
    @stream_buf = ''
  end

  # Listen to the long poll and populate
  # the mongodb.  Threaded.
  def listen
    @thread = Thread.new do
      @log.info "Watching #{@url} (long poll) and pushing events to `#{@index.name}'..."

      begin
        while(!@stop) do
          # Set up callbacks and
          # make the request
          curl = prepare_curl
          curl.perform

          # Wait
          unless @stop
            @log.info "Waiting #{@delay} before re-connecting,,,"
            sleep(@delay)
          end
        end

      rescue StandardError => se
        @log.error "Error in announce watcher: #{se.class}: #{se}"
      ensure
        # Reset so we can be restarted
        @stop = false
      end
    end

    return @thread
  end

  # Stop the request next time the long poll ends
  def stop
    fail "Not currently listening" unless @thread
    @stop = true
  end

  # Is this thread stopping?
  def stopping?
    @stop
  end

  private

  # Prepare cURL with handlers
  # to manage incremental data download
  def prepare_curl

    # Configure curl to give us a string
    curl = Curl::Easy.new(@url)
    curl.autoreferer = true
    curl.on_body do |body_chunk|
      @stream_buf += body_chunk

      process_buffer

      # cURL requires that we return the length of the data
      # we have processed.  That's always all of it, even
      # if we just stuffed it onto the buffer.
      #
      # This rashly assumes that the string length is in bytes
      body_chunk.length
    end

    return curl
  end


  # Process the buffer, extract any IDs,
  # then wipe it.
  def process_buffer

    # Check lines in buffer.
    # If >0, parse each line using JSON and
    # insert the list into mongo
    if @stream_buf.lines.length > 0
      @stream_buf.each_line do |l|

        # Check it's vaguely sane and read the array out of the dodgy JSON line
        next unless(m = l.match(DATA_LINE_RX))
        list = m[:list]

        process_json_list(list)
      end
    end

    # Then clear the buffer entirely
    @stream_buf = ''
  end


  # Parse a valid JSON array of IDs and insert them
  # into mongo.
  #
  # Assumes mongoDB will error on duplicate hash keys.
  def process_json_list(list)

    begin
      json    = JSON.parse(list)

      # Check we have a list of IDs
      # and then construct a record if so
      if json.is_a?(Array)
        json.each do |hash|
          record  = {hash:      hash, 
                     retrieved: false, 
                     added:     Time.now.to_i
          }

          # We want this to fail if it's duped, so we don't
          # overwrite the retrieved: key.
          #
          # This is a hideous abuse of exceptions to handle 
          # logic but it avoids TOCTOU race conditions.
          begin
            @index.save(record)
            @log.info "Added new hash #{hash}"
          rescue Mongo::OperationFailure
            @log.info "Discovered duplicate hash: #{hash}"
          end
        end
      end
    rescue JSON::ParserError
      # meh.
      # XXX: comment this out, probably, because it's pretty paranoid.
      warn "Failed to parse line: #{l}"
    end
  end

end


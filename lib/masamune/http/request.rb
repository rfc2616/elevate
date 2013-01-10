module Masamune
module HTTP
  class HTTPRequest
    METHODS = [:get, :post, :put, :delete, :patch, :head, :options].freeze

    def initialize(method, url, options={})
      raise ArgumentError, "invalid HTTP method" unless METHODS.include? method.downcase
      raise ArgumentError, "invalid URL" unless url.start_with? "http"
      raise ArgumentError, "invalid body type; must be NSData" if options[:body] && ! options[:body].is_a?(NSData)

      @request = NSMutableURLRequest.alloc.init
      @request.CachePolicy = NSURLRequestReloadIgnoringLocalCacheData
      @request.HTTPBody = options[:body]
      @request.HTTPMethod = method
      @request.URL = NSURL.URLWithString(url)
      @response = HTTPResponse.new

      @connection = nil
      @queue = nil
      @promise = Promise.new
    end

    def cancel
      return unless started?

      @connection.cancel()
      @promise.set(nil)
    end

    def response
      unless started?
        start()
      end

      @promise.get()
    end

    def start
      @connection = NSURLConnection.alloc.initWithRequest(@request, delegate:self, startImmediately:false)
      @queue = NSOperationQueue.alloc.init
      @connection.setDelegateQueue(@queue)
      @connection.start()
    end

    def started?
      @connection != nil
    end

    private

    def connection(connection, didReceiveResponse: response)
      @response.headers = response.allHeaderFields
      @response.status_code = response.statusCode
    end

    def connection(connection, didReceiveData: data)
      @response.append_data(data)
    end

    def connection(connection, didFailWithError: error)
      puts "ERROR: #{error.localizedDescription}"

      @response.error = error
      @response.freeze

      @promise.set(@response)
    end

    def connectionDidFinishLoading(connection)
      @response.freeze

      @promise.set(@response)
    end
  end
end
end
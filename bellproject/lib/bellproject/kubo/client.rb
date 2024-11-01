require 'net/http'
require 'uri'
require 'tempfile'
require 'json'
require 'singleton'
require_relative './pin'

module Kubo
  USER_AGENT = 'BellProject'

  class Api
    def build_uri(path, query = {})
      raise 'Method missing'
    end

    def build_request(path, query = {}, &block)
      uri = build_uri(path, query)
      request = Net::HTTP::Post.new(uri)
      request['User-Agent'] = Kubo::USER_AGENT
      block.call(request) if block_given?
      request
    end

    def send(request, &block)
      raise 'Method missing'
    end
  end

  class HttpApi < Api
    def initialize(host, **kwargs)
      @host = host
      @port = kwargs[:port]
      @read_timeout = kwargs[:read_timeout]
    end

    def build_uri(path, query = {})
      URI::HTTP.build(
        host: @host,
        port: @port || URI::HTTP::DEFAULT_PORT,
        path: "/api/v0/#{path}",
        query: URI.encode_www_form(query)
      )
    end

    def send(request, &block)
      http = Net::HTTP.new(request.uri.host, request.uri.port)
      # http.set_debug_output(File.open('debug.txt', 'a'))
      http.read_timeout = @read_timeout if @read_timeout
      http.request(request, &block)
    end
  end

  class HttpsApi < Api
    def initialize(host, **kwargs)
      @host = host
      @port = kwargs[:port]
      @verify_mode = kwargs[:verify_mode]
      @read_timeout = kwargs[:read_timeout]
    end

    def build_uri(path, query = {})
      URI::HTTPS.build(
        host: @host,
        port: @port || URI::HTTPS::DEFAULT_PORT,
        path: "/api/v0/#{path}",
        query: URI.encode_www_form(query)
      )
    end

    def send(request, &block)
      http = Net::HTTP.new(request.uri.host, request.uri.port)
      # http.set_debug_output(File.open('debug.txt', 'a'))
      http.use_ssl = true
      http.verify_mode = @verify_mode if @verify_mode
      http.read_timeout = @read_timeout if @read_timeout
      http.request(request, &block)
    end
  end

  class LocalApi < HttpApi
    include Singleton

    def initialize
      super '127.0.0.1', port: 5001
    end
  end

  class Client
    attr_reader :api

    def initialize(api = nil)
      @api = api || LocalApi.instance
      @user_agent = "BellProject/#{BellProject::VERSION}"
    end

    def add(root, &block)
      boundary = build_boundary

      request = api.build_request('add', {
        'encoding' => 'json',
        # 'r' => true,
        'progress' => true
      })

      request['Transfer-Encoding'] = 'chunked'
      request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"

      node_map = Hash.new

      # Prepare request body
      request.body_stream = build_body_stream do |body|
        node_map[root.path] = root
        body << "--#{boundary}\r\n"
        body << "Content-Disposition: #{root.content_disposition}\r\n"
        body << "Content-Type: #{root.content_type}\r\n"
        body << "\r\n"
        root.depth_first.each do |node|
          next if node == root
          node_map[node.path] = node
          body << "\r\n--#{boundary}\r\n"
          body << "Content-Disposition: #{node.content_disposition}\r\n"
          body << "Content-Type: #{node.content_type}\r\n"
          body << "\r\n"
          if node.file?
            fd = node.open('rb')
            begin
              loop do
                buf = fd.read(4096)
                break if buf.nil?
                body << buf
              end
            ensure
              fd.close()
            end
          end
        end
        body << "\r\n--#{boundary}\r\n"
      end

      uploaded_nodes = []

      # Send and process response
      api.send(request) do |response|
        raise "Request failed: #{response.body}" if !response.kind_of?(Net::HTTPOK)
        response.read_body do |chunk|
          next if chunk.empty?
          upload = nil
          begin
            upload = JSON.parse(chunk)
          rescue JSON::ParserError
          end
          next unless upload
          node = node_map[upload['Name']]
          next unless node
          node.ipfs_hash = upload['Hash']
          bytes = upload['Bytes']
          bytes = Integer(bytes) if bytes
          block.call(node, bytes) if block_given?
          uploaded_nodes << node
        end
      end

      uploaded_nodes
    end

    def list_pins(&block)
      request = api.build_request('pin/ls', {
        'stream': true
      })

      all_pins = []
      api.send(request) do |response|
        raise "Request failed: #{response.body}" if !response.kind_of?(Net::HTTPOK)
        response.read_body do |chunk|
          next if chunk.empty?
          pin = nil
          begin
            pin = JSON.parse(chunk)
          rescue JSON::ParserError
          end
          next unless pin
          pin = Pin.new(pin['Cid'], pin['Type'])
          if block_given?
            block.call(pin)
          else
            all_pins << pin
          end
        end
      end

      all_pins unless block_given?
    end

    def add_pin(cids, recursive = true, &block)
      request = api.build_request('/pin/add', {
        'arg': cids,
        'recursive': true,
        'progress': true,
      })

      api.send(request) do |response|
        raise "Request failed: #{response.body}" if !response.kind_of?(Net::HTTPOK)
        response.read_body do |chunk|
          next if chunk.empty?
          json = nil
          begin
            JSON.parse(chunk)
          rescue JSON::ParserError
          end
          next unless json
          block.call(json) if block_given?
        end
      end
    end

    def build_body_stream(&block)
      io = Tempfile.new('bellproject-kubo-client', binmode: true)
      begin
        block.call(io)
      ensure
        io.close
      end
      File.open(io.path, 'r')
    end

    def build_boundary
      (1..60).map { rand(16).to_s(16) }.join
    end
  end
end

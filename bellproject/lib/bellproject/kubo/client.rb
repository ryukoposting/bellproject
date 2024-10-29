require 'net/http'
require 'uri'
require 'tempfile'
require 'json'

module Kubo
  class Client
    def initialize(host = '127.0.0.1', port = 5001)
      @host = host
      @port = port
    end


    def add(root, &block)
      boundary = build_boundary
      p boundary

      request = build_http_post('add', {
        'encoding' => 'json',
        # 'r' => true,
        'progress' => true
      })

      request['User-Agent'] = 'bellproject'
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
      send(request) do |response|
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

    def build_body_stream(&block)
      io = Tempfile.new('bellproject-kubo-client', binmode: true)
      begin
        block.call(io)
      ensure
        io.close
      end
      File.open(io.path, 'r')
    end

    def build_http_post(path, query = {}, &block)
      uri = build_uri(path, query)
      request = Net::HTTP::Post.new(uri)
      block.call(request) if block_given?
      request
    end

    def build_http_get(path, query = {}, &block)
      uri = build_uri(path, query)
      request = Net::HTTP::Get.new(uri)
      block.call(request) if block_given?
      request
    end

    def build_uri(path, query = {})
      URI::HTTP.build(
        host: @host,
        port: @port,
        path: "/api/v0/#{path}",
        query: URI.encode_www_form(query)
      )
    end

    def build_boundary
      (1..60).map { rand(16).to_s(16) }.join
    end

    def send(request, &block)
      http = Net::HTTP.new(request.uri.host, request.uri.port)
      # http.set_debug_output(File.open('debug.txt', 'a'))
      http.request(request, &block)
    end
  end
end

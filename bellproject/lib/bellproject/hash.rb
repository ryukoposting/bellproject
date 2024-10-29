require_relative './template'

module BellProject
  class IpfsHash < Template
    attr_accessor :name
    attr_accessor :ipfs_hash

    def initialize(name, ipfs_hash)
      @name = name
      @ipfs_hash = ipfs_hash
    end

    def is_root?
      @name == '.'
    end

    def ipfs_gateway_link
      if @name == '.'
        "https://ipfs.io/ipfs/#{@ipfs_hash}"
      else
        "https://ipfs.io/ipfs/#{@ipfs_hash}?filename=#{URI::Parser.new.escape(@name)}"
      end
    end

    def template_file_name
      'templates/hash.erb'
    end
  end
end

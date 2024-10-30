require 'singleton'
require 'pathname'

module BellProject
  class Config
    include Singleton

    attr_reader :root_path

    def initialize
      if ENV.include? 'BELLPATH'
        @root_path = Pathname.new File.expand_path(ENV['BELLPATH'])
      else
        @root_path = Pathname.new File.expand_path('..')
        warn "BELLPATH not defined, using default directory #{@root_path}"
      end
    end

    def pages_path
      unless @pages_path
        @pages_path = @root_path.join('pages')
      end
      @pages_path
    end

    def archives_path
      unless @archives_path
        @archives_path = @root_path.join('archives')
      end
      @archives_path
    end

    def done_path
      unless @done_path
        @done_path = @root_path.join('done')
      end
      @done_path
    end

    def public_path
      unless @public_path
        @public_path = @root_path.join('public')
      end
      @public_path
    end
  end
end

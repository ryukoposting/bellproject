require_relative './template'

module BellProject
  class Nav < Template
    attr_accessor :items
    attr_accessor :show_updir

    def initialize
      @items = []
      @show_updir = true
    end

    def template_file_name
      'templates/nav.erb'
    end
  end
end

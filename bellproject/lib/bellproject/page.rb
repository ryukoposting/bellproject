require_relative './template'
require_relative './header'
require_relative './nav'
require_relative './body'

module BellProject
  class Page < Template
    attr_accessor :title
    attr_accessor :description
    attr_accessor :header
    attr_accessor :nav
    attr_accessor :content_list
    attr_accessor :body

    def initialize(title: 'Bell Project', description: 'Bell Project Historical Software Archive')
      @title = title
      @description = description
      @header = BellProject::Header.new
      @nav = BellProject::Nav.new
      @content_list = BellProject::Nav.new
      @body = BellProject::Body.new('')
    end

    def template_file_name
      'templates/page.erb'
    end
  end
end

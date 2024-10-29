require_relative './template'

module BellProject
  class NavItem < Template
    attr_accessor :path
    def initialize(path)
      @path = path
    end

    def template_file_name
      'templates/nav_item.erb'
    end
  end
end

require_relative './template'

module BellProject
  class Body < Template
    attr_accessor :content
    attr_accessor :children

    def initialize(content)
      @content = content
      @children = []
    end

    def template_file_name
      'templates/body.erb'
    end
  end
end

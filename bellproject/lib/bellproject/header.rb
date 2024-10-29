require_relative './template'

module BellProject
  class Header < Template
    def template_file_name
      'templates/header.erb'
    end
  end
end

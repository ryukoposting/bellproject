require 'erb'

module BellProject
  class Template
    def template_file_name
      raise 'missing method template_file_name'
    end

    def get_binding
      binding
    end

    def render
      rhtml = ERB.new(File.read(template_file_name))
      return rhtml.result(self.get_binding)
    end
  end
end

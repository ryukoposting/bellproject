module Kubo
  class Node
    attr_accessor :parent
    attr_accessor :name
    attr_accessor :ipfs_hash

    def each_child(&block); end

    def file?; false; end
    def folder?; false; end

    def path
      if parent.nil?
        name.to_s
      else
        File.join(parent.path, name.to_s)
      end
    end

    def depth_first
      Enumerator.new do |yielder|
        def depth_first_inner(here, yielder)
          here.each_child do |child|
            depth_first_inner(child, yielder)
          end

          here.each_child do |child|
            yielder << child
          end
        end

        depth_first_inner(self, yielder)
        yielder << self
      end
    end

    def breadth_first
      Enumerator.new do |yielder|
        def breadth_first_inner(here, yielder)
          here.each_child do |child|
            yielder << child
          end

          here.each_child do |child|
            breadth_first_inner(child, yielder)
          end
        end

        yielder << self
        breadth_first_inner(self, yielder)
      end
    end

    def content_disposition
      %Q{form-data; file="#{URI.encode_www_form_component(name)}"; filename="#{URI.encode_www_form_component(path)}"}
    end

    def dump(indent=0)
      puts "#{'  ' * indent}#{name}"
      each_child do |child|
        child.dump(indent + 1)
      end
    end
  end

  class FolderNode < Node
    def initialize(name)
      @children = []
      @name = name
    end

    def folder?; true; end

    def delete(child)
      @children.delete child
      child.parent = nil
    end

    def <<(child)
      child.parent.delete(child) unless child.parent.nil?
      child.parent = self
      @children << child
    end

    def each_child(&block)
      @children.each do |child|
        block.call(child) if block_given?
      end
    end

    def content_type
      'application/x-directory'
    end

    def add_file(name, path = '', &block)
      path = Pathname(path).cleanpath.each_filename.to_a if path.is_a? String
      path.shift while path[0] == '.'

      if path[0].nil?
        node = FileNode.new(name, &block)
        self << node
        return node
      end

      dir = @children.find { |c| c.folder? && c.name == path[0] }
      if dir.nil?
        dir = FolderNode.new(path[0])
        self << dir
      end

      dir.add_file(name, path[1..], &block)
    end
  end

  class FileNode < Node
    attr_reader :size

    def initialize(name, &stream_delegate)
      @name = name
      @stream_delegate = Proc.new(&stream_delegate)
    end

    def open(mode)
      fd = @stream_delegate.call(mode)
      @size = fd.size
      fd
    end

    def file?; true; end

    def content_type
      'application/octet-stream'
    end
  end
end

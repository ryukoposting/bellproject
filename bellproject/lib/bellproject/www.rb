require_relative './config'
require 'pathname'

module BellProject
  module Www
    def self.build
      in_dir = BellProject::Config.instance.pages_path
      out_dir = BellProject::Config.instance.public_path
      build_inner in_dir, out_dir
    end

    private_class_method
    def self.build_inner(in_dir, out_dir)
      puts "Building: #{in_dir}"

      FileUtils.mkdir_p out_dir

      index_html = in_dir.join 'index.html'
      index_md = in_dir.join 'index.md'

      title_txt = in_dir.join 'TITLE'
      description_txt = in_dir.join 'DESCRIPTION'

      page = Page.new
      page.title = "#{File.read(title_txt).strip} / Bell Project" if title_txt.exist?
      page.description = File.read(description_txt).strip if description_txt.exist?
      page.body = if index_html.exist?
        Body.new File.read(index_html)
      elsif File.exist? index_md
        Body.new GitHub::Markup.render(index_md.to_s, File.read(index_md))
      end

      page.nav.show_updir = in_dir != BellProject::Config.instance.pages_path

      hashes_txt = in_dir.join 'HASHES'
      if hashes_txt.exist?
        File.readlines(hashes_txt).each do |line|
          line.strip!
          next if line.length == 0
          ipfs_hash, name = line.split(' ', 2)
          page.body.children << IpfsHash.new(name, ipfs_hash)
        end
      else
        Dir.glob("#{in_dir}/*/").each do |in_subdir|
          in_subdir = Pathname.new(in_subdir)
          path = in_subdir.relative_path_from(Config.instance.pages_path)
          out_subdir = Config.instance.public_path.join(path)
          build_inner(in_subdir, out_subdir)
          page.nav.items << NavItem.new(path)
        end
      end


      out_html = out_dir.join('index.html')
      File.write(out_html, page.render)
    end
  end
end

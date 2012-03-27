require './dropbox-sync'
require 'rdiscount'
require 'mustache'
require 'rss'
require 'digest/md5'


class Updater 
  def initialize
    @config = YAML.load_file('config.yml')

    @plugins = []
    Dir.glob('../plugins/*.server') do |plugin_file|
      class_name = File.basename(plugin_file, ".server")
      require "../plugins/#{class_name}.server/#{class_name}"
      @plugins.push(Object.const_get(class_name.capitalize).new)
    end
  end
  
  def call_plugin_method_with_options(method,options)
    fullOptionsHash = {
      :config => @config,
      :options => options
    }
    return_hash = {}
    @plugins.each do |plugin|
      if plugin.respond_to? method then
        ret = plugin.send(method, fullOptionsHash)
        return_hash.merge!(ret) if ret
      end
    end
    return return_hash
  end
  
  def update 
    # A - Make dropbox session
    d = DropboxSync.new @config['dropbox'] { |url|
      return url
    }

    # B - Download files and create options list
    file_options = []
    d.list @config['dropbox']['path'] do |entry|
      puts "Processing #{entry.path}"

      # setup
      basename = File.basename(entry.path)
      options = {}  
      target_filename = ""

      if basename =~ /.*\.mdown$/ then
        target_filename = "../content/#{basename.gsub(/\.mdown/, '.html')}"
        # 1- tranform file - check for options in 1st line and remove first line if necessary
        content = d.download entry.path do |content|
          arr = content.split("\n")
          if (arr.size > 0) and (arr[0] =~ /^::/) then
            # remove the two colons, then remove spaces, then split them by commas
            arr_options = arr[0].match(/^::(.*)$/)[1].gsub(/ /, '').split(",")
            # convert it into an array that can be used 
            options_hash_array = arr_options.map do |option|
              h = option.split("=>")
              [h[0], h[1]]
            end
            options = Hash[options_hash_array]
            arr.delete_at(0)
          end
          arr.join("\n")
        end

        # 2- convert
        md = RDiscount.new(content)
        html = md.to_html
        File.open(target_filename, 'w') do |file|
          file.puts html
        end

        # 3- set options for publishing
        options['publish'] = (basename =~ /-published.mdown$/)
        if html.match(/<h1>(.*)<\/h1>/) then
          options['title'] = html.match(/<h1>(.*)<\/h1>/)[1] or "No title found"
        else
          options['title'] = "No title found"
        end
        options['updated'] = entry.modified
        begin
          options['description'] = (html.match(/<p>(.*)<\/p>/)[1].gsub(/<\/?[^>]*>/, '').gsub(/\n\n+/, "\n").gsub(/^\n|\n$/, '') or nil) # replace tags and linebreaks
        rescue
          #nothing
        end

      else
        # just download the file (if it doesnt already exist locally)
        target_filename = "../content/#{basename}"
        if !File.exists?(target_filename) or (File.size(target_filename)!=entry.bytes) then
          # download file
          puts "Downloading..."
          File.open(target_filename, "w") do |file|
            file.write d.download(entry.path)
          end
        end
      end


      options["target"] = target_filename
      options['hash'] = (options['pretty'] or Digest::MD5.hexdigest(File.read(target_filename)))
      options['url'] = "#{@config['url']}/index.html#!#{options['hash']}"

      file_options.push(options)
      call_plugin_method_with_options("downloaded_file_with_options", options)
    end

    sorted_file_options = file_options.select { |options| options['publish'] }.sort_by { |option| option['updated'] }.reverse

    # C - generate mapping
    name_file_mapping = Hash[file_options.map do |file|
        [file['hash'], File.basename(file['target'])]
    end]
    name_file_mapping.merge!(name_file_mapping.invert)
    File.open("../content/map.json", "w") do |file|
      file.write JSON.generate(name_file_mapping)
    end

    # D - generate RSS
    last_updated = sorted_file_options.last['updated']
    rss = RSS::Maker.make("2.0") do |maker|
      maker.channel.author = @config['rss']['author']
      maker.channel.updated = last_updated
      maker.channel.title = @config['rss']['title']
      maker.channel.link = @config['url']
      maker.channel.description = @config['rss']['description'] if @config['rss']['description']

      sorted_file_options.each do |file|
        maker.items.new_item do |item|
          item.link = file['url']
          item.title = file['title']
          item.description = file['description'] if file['description']
          item.updated = file['updated']
          item.guid.content = file['hash']
          item.guid.isPermaLink = false
        end
      end
    end

    File.open("../content/feed.rss", "w") do |f|
      f.write rss
    end

    # E - call methods in plugins
    call_plugin_method_with_options("generated_feed_with_files", sorted_file_options)

    # F - generate index.html with server side plugins
    index_html_contents = File.open("../index.html.mustache").read
    mustache_options = call_plugin_method_with_options("render_contents_for_template", file_options)

    # F1 - add dependencies for client side plugins
    js_files = []
    css_files = []
    Dir.glob('../plugins/*.client') do |plugin_file|
      load_config = YAML.load_file("#{plugin_file}/load.yml")
      js_files |= load_config['js'].map { |file| 
        if file =~ /:\/\// then
            file
        else
          "plugins/#{File.basename(plugin_file)}/#{file}"
        end
      } if load_config['js']

      css_files |= load_config['css'].map { |file| 
        if file =~ /:\/\// then
            file
        else
          "plugins/#{File.basename(plugin_file)}/#{file}"
        end
      } if load_config['css']  
    end

    mustache_options[:additional_js] = js_files.map { |file| "<script type='text/javascript' src='#{file}'></script>"}.join("\n") if (js_files.size > 0)
    mustache_options[:additional_css] = css_files.map { |file| "<link rel='stylesheet' href='#{file}' type='text/css'>"}.join("\n") if (css_files.size > 0)

    File.open("../index.html", "w") do |f|
      f.write Mustache.render(index_html_contents, mustache_options)
    end
    
    return false
  end
end
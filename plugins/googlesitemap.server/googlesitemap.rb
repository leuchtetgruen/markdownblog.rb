class Googlesitemap
  def generated_feed_with_files(options)
    File.open("../content/sitemap-xml.txt", "w") do |f|
      base_url = options[:config]['url']
      f.puts base_url
      
      files = options[:options]
      files.each do |file|
        f.puts file['url'].gsub(/\/index.*/, "/plugins/googlesitemap.server/search-engine.php?name=#{file['hash']}" )
      end
    end
  end
end
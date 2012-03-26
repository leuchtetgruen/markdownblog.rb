class Pagebar
  def render_contents_for_template(options)
    ret = "<ul>"
    options[:config]['pages'].each_with_index do |h, idx|
      id = h.keys.first
      title = h.values.first
      link = options[:options].find { |file| file['hash'] == id }
      next if (!link) 
      link = link['url']
      ret += "<li><a href='#{link}'>#{title}</a></li>"
      ret += "&nbsp;|&nbsp;" if (idx < (options[:config]['pages'].size - 1))
    end
    ret += "</ul>"
    
    return { 'page_bar' => ret }
  end
end
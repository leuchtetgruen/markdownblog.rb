class HashConfig
  
  def initialize(hash, config)
    @hash = hash
    @config = config
  end
  
  def render(target, title)
    s = "<form action='#{target}' method='post'>\r\n"
    s += render_without_form_tags(@hash, @config, title)
    s += "<input type='submit' value='Send' />\r\n"
    s += "</form>\r\n"
    return s
  end
  
  def render_without_form_tags(h, c, title)    
    s = ""
    s  += "<h1>#{title}</h1>" if title
    s  += "<table class='hc_table'>\r\n"
    h.each do |k, v|
      next if (c[:white_list] and (!c[:white_list].include?(k)))
      next if (c[:black_list] and (c[:black_list].include?(k)))
      
      c[k] = {} if !c[k] #initialize
      
       k_name = if (c[k][:prefix]) then
                  c[k][:prefix] + "." + k
                else
                  k
                end
       k_description = (c[k][:description] or k.capitalize)  # description defined in config or real key
       v_show = (c[k][:value] ? c[k][:value] : v) # value defined in config or this value
       v_type = (c[k][:type] or 'text') # type defined in config or 'text'
       v_placeholder = "placeholder='#{c[k][:placeholder]}'" if c[k][:placeholder]
       s += "<tr>\r\n"
       if (v.class==Hash) then
         s += "<td></td>\r\n"
         s += "<td>" + render_without_form_tags(v, (c[k] or {}), k_name) + "</td>\r\n"
       else
         s += "<td class='hc_label'><label for='#{k_name}'>#{k_description}</label></td>\r\n"         
         s += "<td class='hc_input'><input type='#{v_type}' name='#{k_name}' value='#{v_show}' #{v_placeholder}/></td>\r\n"         
       end
       s += "</tr>\r\n"
    end
    s += "</table>\r\n"
    return s
  end
  
end
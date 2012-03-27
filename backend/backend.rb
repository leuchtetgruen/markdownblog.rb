require 'rubygems' if RUBY_VERSION < "1.9"
require 'yaml'
require 'sinatra/base'
require './hash_config'
require './update'
require './dropbox-sync'
require 'rdiscount'

module YAML
  def self.save_file(obj, file_name)
    File.open(file_name, 'w') do |f|
      f.puts YAML::dump(obj)
    end
  end
end

class MarkdownBlogBackend < Sinatra::Base
  set :static, true
  set :public_folder, File.dirname(__FILE__) + '/public'
  set :port, 8080

  @config = YAML.load_file('config.yml')
  
  use Rack::Auth::Basic, "MarkdownBlog - Backend. Please authenticate" do |username, password|
    [username, password] == [@config['backend']['username'], @config['backend']['password']]
  end
  
  
  get '/' do
    redirect "admin.html"
  end
  
  get '/dropbox' do
    c = YAML.load_file('config.yml')
    cc = {
      'app_key' => {
        :description => 'Application Key',
        :placeholder => 'app key',
        :value => ''
      },
      'app_secret' => {
        :description => 'Application Secret',
        :placeholder => 'app secret',
        :value => ''        
      },
      'path' => {
        :description => 'Post path'
      }
    }
    
    
    hc = HashConfig.new(c['dropbox'], cc)
    hc.render("/save_dropbox", "Dropbox")
  end
  
  post '/save_dropbox' do
    c = YAML.load_file('config.yml')
    ['app_key', 'app_secret', 'path'].each { |i|
      c['dropbox'][i] = params[i] if (params[i] and (params[i].length > 0))
    }
    YAML::save_file(c, 'config.yml')
    redirect "admin.html"
  end

  get '/rss' do
    c = YAML.load_file('config.yml')
    hc = HashConfig.new(c['rss'], {})
    hc.render("/save_rss", "RSS")
  end
  
  post '/save_rss' do
    c = YAML.load_file('config.yml')
    ['author', 'title', 'description'].each { |i|
      c['rss'][i] = params[i] if (params[i] and (params[i].length > 0))
    }
    YAML::save_file(c, 'config.yml')
    redirect "admin.html"
  end
  
  get '/url' do
    c = YAML.load_file('config.yml')
    hc = HashConfig.new(c, {:white_list => ['url']})
    hc.render("/save_url", "URL")
  end
  
  post '/save_url' do
    c = YAML.load_file('config.yml')
    c['url'] = params['url'] if params['url']
    YAML::save_file(c, 'config.yml')
    redirect "admin.html"
  end
  
  get '/admin_login' do
    c = YAML.load_file('config.yml')
    hc = HashConfig.new(c['backend'].merge({'password2' => '', 'cur_password' => ''}), {
      'password' => {
        :type => 'password',
        :value => ''
      },
      'password2' => {
        :type => 'password',
        :value => '',
        :description => 'Password (repeat)'
      },
      'cur_password' => {
        :type => 'password',
        :value => '',
        :description => 'Current password'
      }      
    })
    hc.render("/save_admin_login", "Login")
  end
  
  post '/save_admin_login' do
    c = YAML.load_file('config.yml')    
    if (params['password']!=params['password2']) then
       "The two passwords do not match!"
    elsif (params['cur_password']!=c['backend']['password']) then
       "The current password was wrong"
    else
      ['username', 'password'].each { |i|
        c['backend'][i] = params[i] if (params[i] and (params[i].length > 0))
      }
      YAML::save_file(c, 'config.yml')
      redirect "admin.html"
    end
  end
  
  get '/update_blog' do
    puts "UPDATE!!!!"
    u = Updater.new
    r = u.update
    if (r) then
      "Please visit <a href='#{r}' target='_blank'>this Dropbox auth page</a> to allow access to your dropbox and restart the update."
    else
      c = YAML.load_file('config.yml')
      "Updated your blog. Visit <a href='#{c['url']}' target='_blank'>your blog</a>"
    end
  end
  
  get '/plugins' do
    server_plugins = []
    server_plugins_available = []
    client_plugins = []
    client_plugins_available = []    
    Dir.glob('../plugins/*.server') do |plugin_file|
      server_plugins.push(File.basename(plugin_file, ".server"));
    end
    Dir.glob('../plugins-available/*.server') do |plugin_file|
      server_plugins_available.push(File.basename(plugin_file, ".server"));
    end    
    Dir.glob('../plugins/*.client') do |plugin_file|
      client_plugins.push(File.basename(plugin_file, ".client"));
    end
    Dir.glob('../plugins-available/*.client') do |plugin_file|
      client_plugins_available.push(File.basename(plugin_file, ".client"));
    end    
    
    s  = "<h1>Server Plugins</h1>\r\n"
    s += "<h2>installed</h2>\r\n"
    s += "<ul>\r\n"
    server_plugins.each do |plugin|
      s += "<li><a href='/delete_plugin?name=#{plugin}.server'>-</a>#{plugin}</li>\r\n"
    end
    s += "</ul>\r\n"
    s += "<h2>available</h2>\r\n"
    s += "<ul>\r\n"
    server_plugins_available.each do |plugin|
      s += "<li><a href='/add_plugin?name=#{plugin}.server'>+</a>#{plugin}</li>\r\n"
    end
    s += "</ul>\r\n"
    
    s += "<h1>Client Plugins</h1>\r\n"
    s += "<h2>installed</h2>\r\n"
    s += "<ul>\r\n"
    client_plugins.each do |plugin|
      s += "<li><a href='/delete_plugin?name=#{plugin}.client'>-</a>#{plugin}</li>\r\n"
    end
    s += "</ul>\r\n"
    s += "<h2>available</h2>\r\n"
    s += "<ul>\r\n"
    client_plugins_available.each do |plugin|
      s += "<li><a href='/add_plugin?name=#{plugin}.client'>+</a>#{plugin}</li>\r\n"
    end
    s += "</ul>\r\n"    
    
    s += "<b>You will need to update your blog after installing/uninstalling plugins!</b>"
    
    s
  end
  
  get '/delete_plugin' do
    cmd = "mv ../plugins/#{params[:name]} ../plugins-available/#{params[:name]}"
    system(cmd)
    redirect "admin.html"
  end
  
  get '/add_plugin' do
    cmd = "mv ../plugins-available/#{params[:name]} ../plugins/#{params[:name]}"
    system(cmd)
    redirect "admin.html"    
  end
  
  post '/preview' do
    md = RDiscount.new(params[:data])
    md.to_html
  end
  
  post '/upload' do
    c = YAML.load_file('config.yml')    
    d = DropboxSync.new(c['dropbox'])

    d.upload("#{c['dropbox']['path']}/#{params[:filename]}", params[:data])  
  end
  
  get '/list' do
    c = YAML.load_file('config.yml')    
    d = DropboxSync.new(c['dropbox']) do |url|
      return "Please visit the <a href='#{url}' target='_blank'>Dropbox authorization page</a>, so this software can access your dropbox."
    end
    
    s  = "<ul>\r\n"
    d.list(c['dropbox']['path']) do |entry|
      f = File.basename(entry.path)
      s += "<li><a href='#' onclick='loadFile(\"#{f}\");'>#{f}</a></li>\r\n" if (f =~ /\.mdown/)
    end
    s += "</ul>\r\n"
    s
  end
  
  get '/load' do
    c = YAML.load_file('config.yml')    
    d = DropboxSync.new(c['dropbox'])
    d.download("#{c['dropbox']['path']}/#{params[:filename]}")
  end
end

MarkdownBlogBackend.run!
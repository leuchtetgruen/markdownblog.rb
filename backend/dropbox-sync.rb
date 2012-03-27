require 'dropbox'
require 'pathname'

class DropboxSync
  @@AUTHORIZED_SERIALIZED_FILENAME = 'cache/authorized_dropbox_session.txt'
  @@UNAUTHORIZED_SERIALIZED_FILENAME = 'cache/unauthorized_dropbox_session.txt'  
  
  attr_accessor :session
  
  def initialize(config)
    if File.exists?(@@AUTHORIZED_SERIALIZED_FILENAME)
      @session = Dropbox::Session.deserialize(File.read(@@AUTHORIZED_SERIALIZED_FILENAME)) 
    elsif File.exists?(@@UNAUTHORIZED_SERIALIZED_FILENAME)
      @session = Dropbox::Session.deserialize(File.read(@@UNAUTHORIZED_SERIALIZED_FILENAME)) 
      begin
        @session.authorize
        puts "Successfully authorized"
        File.open(@@AUTHORIZED_SERIALIZED_FILENAME, 'w') do |f|
          f.puts @session.serialize
        end
      rescue
        puts "Error - could not authorize"
      end
      File.delete(@@UNAUTHORIZED_SERIALIZED_FILENAME)
    else
      @session = Dropbox::Session.new(config['app_key'], config['app_secret'])
      @session.mode = :dropbox
      File.open(@@UNAUTHORIZED_SERIALIZED_FILENAME, 'w') do |f|
        f.puts @session.serialize
      end
      yield @session.authorize_url if block_given?      
    end
  end
  
  def list(path)
    list = @session.list(path)
    list.reject! {
      |entry|
      !(yield entry)
    } if block_given?
    return list
  end
  
  def download(path)
    content = @session.download(path)
    if block_given? then
      return yield content
    else
      return content
    end
  end
  
  def upload(path, content)  
    tf = Tempfile.new(File.basename(path))
    tf.write(content)
    tf.close    
    @session.upload(tf.path, Pathname.new(path).split[0].to_s, {as: File.basename(path)})
    tf.unlink
  end
end

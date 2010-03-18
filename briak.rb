require 'rubygems'
require 'ripple'
require 'sinatra'
require 'erb'
require 'uri'

enable :sessions

get '/' do 
  @bucket = nil
  @keys = []
  @key = nil
  @robject = nil
  @flash = params[:flash]
  erb :index
end

post '/config' do
  begin
    puts params.to_yaml
    session[:host] = params[:host] if params[:host] && params[:host].length > 0
    session[:port] = params[:port] if params[:port] && params[:port].length > 0
    create("briak", "bucket_names", params[:bucket_names]) if params[:bucket_names] && params[:bucket_names].length > 0
    redirect '/'
  rescue Exception => e
    @flash = e.message
    erb :index
  end
end

get '/get/:bucket' do |bucket|
  @bucket = bucket
  @keys = client[bucket].keys.sort
  @key = nil
  @robject = nil
  @flash = params[:flash]
  erb :index
end

get %r{/get/([^/]+)/(.*)} do |bucket, key|
  @bucket = bucket
  @keys = client[bucket].keys.sort
  @key = key
  @robject = find(bucket,key)
  @flash = params[:flash]
  erb :index
end

post %r{/put/([^/]+)/(.*)} do |bucket, key|
  @bucket = bucket
  @keys = client[bucket].keys.sort
  @key = key
  @robject = find(bucket,key)
  @flash = params[:flash]
  if params[:operation] == "Update"
    if params[:link_bucket] != "Bucket" && params[:link_key] != "Key" && params[:link_rel]
      o = find(params[:link_bucket], params[:link_key])
      begin 
        @robject.links << o.to_link(params[:link_rel].gsub(/[^[:alnum:]]/,'')) 
      rescue Exception => e
        @flash = "ERROR: Invalid Bucket/Key combination"
        puts @flash
      end
    end
    @robject.content_type = params[:content_type]
    @robject.data = @robject.content_type == "application/json" ? ActiveSupport::JSON.decode(params[:data]) : params[:data]
    @robject.store
    redirect "/get/#{@bucket}/#{@key}?flash=#{URI.escape(@flash) if @flash}"
  elsif params[:operation] == "Delete"
    @robject.delete
    @flash = "Deleted key: #{@key}"
    redirect "/get/#{@bucket}?flash=#{URI.escape(@flash) if @flash}"
  elsif params[:operation] == "Eval"
    @robject.data = params[:data]
    @robject.store
    begin
      @results = eval(params[:data])
    rescue Exception => e
      @results = "Error in Eval: #{e.message}"
    end
    erb :index
  end
end

post '/newkey/:bucket' do |bucket|
  create(bucket, params[:key], "")
  redirect "/get/#{bucket}"
end

post '/delete_bucket/:bucket' do |bucket|
  client[bucket].keys.each {|key|
    puts "deleting #{key}..."
    find(bucket,key).delete
  }
  redirect "/"
end
    

get '/remove_link/:bucket/:key/:link_bucket/:link_key/:link_rel' do |bucket, key, link_bucket, link_key, link_rel|
  o = find(bucket,key)
  o.links = o.links.select{ |link|
    [link.bucket, link.key, link.rel] != [link_bucket, link_key, link_rel]
  }
  o.store
  redirect "/get/#{bucket}/#{key}"
end

get '/test1' do
  (1..100).each do |i|
    puts "Saving item #{i}"
    p = Riak::RObject.new(client['test'], "Parent#{i}")
    p.content_type = "application/javascript"
    p.data = {:item => 'one', :batch => i / 10}.to_json
    p.store
    (1..100).each do |j|
      c = Riak::RObject.new(client['test'], "Child#{j}")
      c.content_type = "application/javascript"
      c.data = {:item => 'one', :batch => j / 10}.to_json
      c.store
      p.links << c.to_link("parent")
      p.store
    end
  end
end



private
def client
  @client ||= Riak::Client.new(:host => session[:host], :port => session[:port].to_i)
end

def bucket_names
  @bn ||= find("briak", "bucket_names").data.split(" ") rescue []
end

def create(bucket,key, data, content_type=nil)
  key = key.gsub(/\s/,'') if key
  b = bucket.is_a?(Riak::Bucket) ? bucket : client.bucket(bucket) 
  n = Riak::RObject.new(b, key)
  content_type = data.is_a?(String) ? "text/plain" : "text/yaml" unless content_type
  n.content_type = content_type
  n.data = data
  n.store
end

def find(bucket, key)
  begin
    bucket = client[bucket] unless bucket.respond_to?(:get)
    bucket.get(key)
  rescue Riak::FailedRequest => fr
    return nil if fr.code.to_i == 404
    raise fr
  end
end

# Renders out the appropriate HTML for each content type
helpers do
  def render_data(bucket, key, robject)
    case 
    when robject.content_type =~ %r{application/json}
        %Q{<textarea id="key-data" name="data" spellcheck="false">#{robject.data.to_json}</textarea>}
      when robject.content_type =~ %r{image}
        %Q{<div id="image-data"><image src="http://#{session[:host]}:#{session[:port]}/riak/#{bucket}/#{key}" /></div>}
      else
        %Q{<textarea id="key-data" name="data" spellcheck="false">#{robject.data.to_s}</textarea>}
    end
  end  
end


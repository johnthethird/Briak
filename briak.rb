require 'rubygems'
require 'sinatra'
require 'ripple'
require 'erb'

enable :sessions

get '/' do 
  @bucket = nil
  @keys = []
  @key = nil
  @robject = nil
  @flash = nil
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
  erb :index
end

get '/get/:bucket/:key' do |bucket, key|
  @bucket = bucket
  @keys = client[bucket].keys.sort
  @key = key
  @robject = find(bucket,key)
  erb :index
end

post '/put/:bucket/:key' do |bucket, key|
  @bucket = bucket
  @keys = client[bucket].keys.sort
  @key = key
  @robject = find(bucket,key)
  if params[:operation] == "Update"
    @robject.data = params[:data]
    @robject.store
  elsif params[:operation] == "Delete"
    @robject.delete
  end
  redirect "/get/#{@bucket}/#{@key}"
end

post '/newkey/:bucket' do |bucket|
  create(bucket, params[:key], "")
  redirect "/get/#{bucket}"
end
    
get '/seed1' do
  data = %w{dog cat horse bee bird bug}
  BUCKETS.each do |bucket_name|
    bucket = client[bucket_name]
    (1..100).each do |i|
      create(bucket, "key#{i}", data[rand(5)])
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


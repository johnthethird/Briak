require 'rubygems'
require 'sinatra'
require 'ripple'
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

get '/get/:bucket/:key' do |bucket, key|
  @bucket = bucket
  @keys = client[bucket].keys.sort
  @key = key
  @robject = find(bucket,key)
  @flash = params[:flash]
  erb :index
end

post '/put/:bucket/:key' do |bucket, key|
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
    @robject.data = params[:data]
    @robject.store
    redirect "/get/#{@bucket}/#{@key}?flash=#{URI.escape(@flash) if @flash}"
  elsif params[:operation] == "Delete"
    @robject.delete
    redirect "/get/#{@bucket}/#{@key}"
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

get '/remove_link/:bucket/:key/:link_bucket/:link_key/:link_rel' do |bucket, key, link_bucket, link_key, link_rel|
  o = find(bucket,key)
  o.links = o.links.select{ |link|
    [link.bucket, link.key, link.rel] != [link_bucket, link_key, link_rel]
  }
  o.store
  redirect "/get/#{bucket}/#{key}"
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

module Riak
  class Link
    attr_accessor :bucket
    attr_accessor :key
    def initialize(url, rel)
      @url, @rel = url, rel
      @bucket, @key = $1, $2 if @url =~ %r{/raw/([^/]+)/([^/]+)/?}
    end
  end
end
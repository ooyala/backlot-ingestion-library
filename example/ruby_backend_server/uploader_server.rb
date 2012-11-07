require "rubygems"
require "sinatra/base"
require "json"
require "net/http"
require "cgi"
require "coffee-script"
require "pinion"
require "pinion/sinatra_helpers"
require_relative "lib/ooyala_api"

class UploaderServer < Sinatra::Base
  API_KEY = ENV["API_KEY"] || "SAMPLE_API_KEY"
  SECRET = ENV["SECRET"] || "SAMPLE_SECRET"
  V2_API_URL = ENV["V2_API_URL"] || "http://localhost:7080"

  set :pinion, Pinion::Server.new("/assets")
  set :protection, :except => :path_traversal  # Without this, any double slash (//) is removed

  helpers Pinion::SinatraHelpers

  configure do
    pinion.convert :coffee => :js
    pinion.watch "public"
    enable :logging
  end

  get "/" do
    erb :index
  end

  before "/v2/?*" do
    @ooyala_api = Ooyala::API.new(API_KEY, SECRET, { :base_url => V2_API_URL })
  end

  post "/v2/assets" do
    @ooyala_api.post("assets", params)
  end

  before "/v2/assets/:embed_code/?*" do
    @id = params["embed_code"]
    @clean_params = params.remove_sinatra_params!("embed_code")
  end

  get "/v2/assets/:embed_code/uploading_urls" do
    @ooyala_api.get("assets/#{@id}/uploading_urls", @clean_params)
  end

  put "/v2/assets/:embed_code/upload_status" do
    @ooyala_api.put("assets/#{@id}/upload_status", @clean_params)
  end

  post "/v2/assets/:embed_code/labels" do
    raw = request.env["rack.input"].read
    @ooyala_api.post("assets/#{@id}/labels", raw)
  end

  # Label paths must start with a slash and must not end with a slash
  post "/v2/labels/by_full_path/*" do
    paths = params[:splat].first
    params.remove_sinatra_params!
    @ooyala_api.post("labels/by_full_path/#{paths}", params)
  end

end

class Hash
  # Parameters added by sinatra are not part of the request, so they shouldn't be sent to the ooyala server
  # They should be removed
  def remove_sinatra_params!(*keys)
    keys.push("splat")
    keys.push("captures")
    keys.each{|key| self.delete(key)}
    return self
  end
end

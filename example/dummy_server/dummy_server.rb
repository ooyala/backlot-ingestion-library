# This server simulates a basic version of the Ooyala V2 Upload APIs. It can be used to test the
# backlot ingestion library without hitting the actual Backlot APIs

require "rubygems"
require "sinatra/base"
require "json"
require "uuidtools"

MAX_JSON_REQUEST_BODY_SIZE = 1024 * 100 # 100K should be enough for all customer use cases.

class DummyServer < Sinatra::Base
  configure do
    enable :logging
  end

  set :protection, :except => :path_traversal  # Without this, any double slash (//) is removed

  before do
    content_type :json
    headers("Access-Control-Allow-Origin" => request.env["HTTP_ORIGIN"]) if request.env["HTTP_ORIGIN"]
  end

  get "/" do
    ""
  end

  options "/v2/assets" do
    headers("Access-Control-Allow-Methods" => "POST, OPTIONS")
    ""
  end

  post "/v2/assets" do
    movie_hash = JSON.parse(request.body.read)
    new_movie = movie_hash.merge(:embed_code => UUIDTools::UUID.random_create.hexdigest)
    new_movie.to_json
  end

  options "/v2/assets/:embed_code/uploading_urls" do
    headers("Access-Control-Allow-Methods" => "GET, OPTIONS")
    ""
  end

  # The ooyala server will return a number of urls depending on the file and chunk size
  # Here, a fixed number of urls is sent to keep the testing simple
  get "/v2/assets/:embed_code/uploading_urls" do
    id = params["embed_code"]
    ["http://localhost:7080/#{id}/00000001-00100000",
     "http://localhost:7080/#{id}/00100001-00200000",
     "http://localhost:7080/#{id}/00200001-00250000"].to_json
  end

  options "/:embed_code/:file_name" do
    headers("Access-Control-Allow-Methods" => "PUT, OPTIONS")
    ""
  end

  put "/:embed_code/:file_name" do
    string_io = request.body # will return a StringIO
    data_bytes = string_io.read # read the stream as bytes
    filename = env['HTTP_X_FILE_NAME'] # This will be the actual filename of the uploaded file
    response.status = 200
  end

  options "/v2/assets/:id/upload_status" do
    headers("Access-Control-Allow-Methods" => "PUT, OPTIONS")
    ""
  end

  put "/v2/assets/:id/upload_status" do
    status_hash = JSON.parse(request.body.read)
    { :status => status_hash["status"] }.to_json
  end

  options "/v2/labels/by_full_path/*" do
    headers("Access-Control-Allow-Methods" => "POST, OPTIONS")
    ""
  end

  post "/v2/labels/by_full_path/*" do
    label_paths = params[:splat].first.split(",")
    label_paths.each do |label_path|
      show_error(400, "Label path must start with a slash.") unless label_path[0].chr == "/"
      show_error(400, "Label path must not end with a slash.") if label_path[-1].chr == "/"
      path_components = label_path[1..-1].split("/")
      show_error(400, "Invalid label name: #{label_path}") if path_components.any? { |c| c.nil? || c.empty? }
    end

    [{
      :parent_id => "92e38b744b0c45e58c1bc022c03fcf54",
      :full_name => "/one/full/path/label",
      :name => "label",
      :id => "d23dc4c9871a4adebb02671a5470273e"
    },{
      :parent_id => "16e658cc8ec7414fa237dbb5c30d9817",
      :full_name =>"/my/label/is/great",
      :name => "great",
      :id => "2422a8d5a5af40b6a0add20c237c8d4d"
    }].to_json
  end

  options "/v2/assets/:embed_code/labels" do
    headers("Access-Control-Allow-Methods" => "POST, OPTIONS")
    ""
  end

  post "/v2/assets/:embed_code/labels" do
    label_ids = enforce_valid_json_body
    show_error(400, "Post body must be a list of label ids") unless label_ids.is_a?(Array)
    label_ids.each do |label_id|
      unless label_id.is_a?(String) || label_id.is_a?(Integer)
        show_error(400, "Post body must be a list of label ids")
      end
    end

    {
      :items => [{
        :parent_id => "16e658cc8ec7414fa237dbb5c30d9817",
        :full_name => "/my/label/is/great",
        :name => "great",
        :id => "2422a8d5a5af40b6a0add20c237c8d4d"
      },{
        :parent_id => "92e38b744b0c45e58c1bc022c03fcf54",
        :full_name => "/one/full/path/label",
        :name => "label",
        :id => "d23dc4c9871a4adebb02671a5470273e"
      }]
    }.to_json
  end

end

# Shows an error message in JSON, and sets the response status code.
def show_error(status_code, message) halt(status_code, { :message => message }.to_json) end

def enforce_valid_json_body
  request_body = request.env["rack.input"].read
  # Cap the size of the JSON request body; parsing a huge request will make our memory usage soar.
  # TODO(philc): We may want to log this. It's a strange occurence.
  if request.env["CONTENT_LENGTH"].to_i > MAX_JSON_REQUEST_BODY_SIZE
    show_error 400, "Your JSON request body is too large."
  end
  if request_body.nil? || request_body.empty?
    show_error 400, "This URL requires a request body in JSON format. Your request's body is blank."
  end
  json_body = JSON.parse(request_body) rescue nil
  show_error 400, "Invalid JSON in the request body." if json_body.nil?
  json_body
end

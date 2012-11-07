require "bundler/setup"
require "minitest/autorun"
require "scope"
require "watir"
require "net/http"

class UploadTest < Scope::TestCase

  setup_once do
    ensure_reachable "http://localhost:7081", "API proxy"
    ensure_reachable "http://localhost:7080", "dummy server"
    @@browser = Watir::Browser.new
    @@browser.goto "http://localhost:7081"
  end

  teardown_once do
    @@browser.close
  end

  context "upload movie" do
    should "upload a simple file" do
      local_file = File.join(File.dirname(File.expand_path(__FILE__)), "empty.flv")
      @@browser.file_field.set local_file
      sleep 2
      assert @@browser.div(:id => "messages").text.include? "Completed"
    end
  end

  def ensure_reachable(server_url, server_display_name = nil)
    return if server_reachable?(server_url)
    failure_message = server_display_name ? "#{server_display_name} at #{server_url}" : server_url
    puts "FAIL: Unable to connect to #{failure_message}"
    exit 1
  end

  def server_reachable?(server_url)
    uri = URI.parse(server_url)
    request = Net::HTTP.new(uri.host, uri.port)
    request.read_timeout = 2
    response = nil
    get_request = Net::HTTP::Get.new(uri.request_uri)
    begin
      response = request.request(get_request)
    rescue StandardError, Timeout::Error
    end
    !response.nil? && response.code.to_i == 200
  end
end

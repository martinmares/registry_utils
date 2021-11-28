module HarborUtils

  require 'faraday'
  require 'base64'

  class Client

    attr_reader :url, :api_path, :connection

    HTTP_STATUS_OK = 200

    def initialize(url, user, pass)
      @url = url
      @user = user
      @pass = pass
      @connection = Faraday.new(
        url: @url,
        headers: {"Content-Type" => "application/json",
                  "Authorization" => basic_auth}
      )
    end

    def get(url, params = nil, headers = nil)
      @connection.get url, params, headers
    end

    def ok?(status)
      status == HTTP_STATUS_OK
    end

    private

    def basic_auth
      encode_user_pass = Base64.strict_encode64 "#{@user}:#{@pass}"
      "Basic #{encode_user_pass}"
    end

  end

end

module HarborUtils

  require "json"
  require "awesome_print"

  class Utils

    def self.parse_response(response)
      status = response.status
      json = JSON.parse(response.body)
      [status, json]
    end

  end

end

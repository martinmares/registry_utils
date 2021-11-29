module HarborUtils

  require "json"
  require "awesome_print"

  class Utils

    def self.parse_response(response)
      status = response.status
      json = JSON.parse(response.body)
      [status, json]
    end

    def self.date_time_simple(dt)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end

    def self.blank?(var)
      var.nil? || var.empty?
    end

  end

end

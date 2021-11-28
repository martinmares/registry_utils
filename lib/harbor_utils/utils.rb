module HarborUtils

  require "json"
  require "awesome_print"
  require "action_view"

  class Utils

    include ActionView::Helpers::DateHelper

    def self.parse_response(response)
      status = response.status
      json = JSON.parse(response.body)
      [status, json]
    end

    def time_ago(date_time)
      distance_of_time_in_words(Time.now, date_time)
    end

    def self.date_time_simple(dt)
      "#{dt.year}-#{dt.month}-#{dt.day}"
    end

  end

end

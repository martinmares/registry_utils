module HarborUtils

  require "awesome_print"
  require "paint"
  require_relative "client"
  require_relative "utils"

  class Api

    def initialize(url, user, pass)
      @client = HarborUtils::Client.new(url, user, pass)
      @api_path = "api/v2.0"
    end

    def api_endpoint
      "#{@client.url}#{@api_path}"
    end

    def health_endpoint
      "#{@api_path}/health"
    end

    def healthy?(status)
      status.downcase.start_with?("health")
    end

    def health
      response = @client.get health_endpoint
      status, body = Utils::parse_response(response)
      if @client.ok?(status)
        if healthy?(body["status"])
          puts "Harbor is #{Paint["healthy!", :green]}"
        else
          puts "Harbor is #{Paint["unhealthy!", :red]}"
        end
        health_of_components(body)
      end
    end

    def health_of_components(body)
      if body.has_key? "components"
        puts "Status of each component:"
        body["components"].each do |component|
          print_component_health(component["name"], component["status"])
        end
      end
    end

    private

    def print_component_health(name, status)
      if healthy?(status)
        puts "  ==> #{Paint[name, :yellow]} is #{Paint["healthy!", :green]}"
      else
        puts "  ==> component #{Paint[name, :yellow]} is #{Paint["unhealthy!", :red]}"
      end
    end

  end

end

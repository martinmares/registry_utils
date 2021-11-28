module HarborUtils

  require "awesome_print"
  require "paint"
  require_relative "client"
  require_relative "utils"

  class Api

    def initialize(url, user, pass, project_name, keep_images, keep_days)
      @client = HarborUtils::Client.new(url, user, pass)
      @project_name = project_name
      @keep_images = keep_images
      @keep_days = keep_days
      @api_path = "api/v2.0"
    end

    def api_endpoint
      "#{@client.url}#{@api_path}"
    end

    def health_endpoint
      "#{@api_path}/health"
    end

    def list_of_projects_endpoint
      "#{@api_path}/projects?page_size=100"
    end

    def healthy?(status)
      status.downcase.start_with?("health")
    end

    def call(what)
      case what
      when :health
        call_health()
      when :projects
        call_projects()
      end
    end

    private

    def call_health
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

    def print_component_health(name, status)
      if healthy?(status)
        puts "  ==> #{Paint[name, :yellow]} is #{Paint["healthy!", :green]}"
      else
        puts "  ==> #{Paint[name, :yellow]} is #{Paint["unhealthy!", :red]}"
      end
    end

    def call_projects
        if @project_name
          puts "For project #{Paint[@project_name, :yellow]}"
        else
          puts "Project list:"
          call_list_of_projects()
        end
    end

    def call_list_of_projects
      response = @client.get list_of_projects_endpoint
      status, body = Utils::parse_response(response)
      if @client.ok?(status)
        print_list_of_projects(body)
      end
    end

    def print_list_of_projects(body)
      if body.is_a?(Array)
        body.each do |project|
          # name, project_id, creation_time, repo_count
          puts " ==> #{Paint[project["name"], :cyan]}, created: #{Paint[project["creation_time"], :yellow]}, id: #{Paint[project["project_id"], :green]}, repos: #{Paint[project["repo_count"], :green]}"
        end
      end
    end

  end

end

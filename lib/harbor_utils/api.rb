module HarborUtils

  require "awesome_print"
  require "paint"
  require_relative "client"
  require_relative "utils"

  PAGE_SIZE = 10
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
      "#{@api_path}/projects"
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
      when :info
        call_info()
      end
    end

    private

    def call_health
      response = @client.get(health_endpoint)
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

    def total_count(response)
      result = 0
      if response.headers.has_key? "x-total-count"
        x_total_count = response.headers["x-total-count"].to_i
        total_pages = (x_total_count.to_f / PAGE_SIZE.to_f).ceil
        result = (total_pages - 1) if total_pages > 1
      end
      result
    end

    def call_list_of_projects
      response = @client.get(list_of_projects_endpoint, { page_size: PAGE_SIZE })
      status, body = Utils::parse_response(response)
      if @client.ok?(status)
        print_list_of_projects(body, 1)
        cnt = total_count(response)
        if cnt > 0
          1.upto(cnt) do |page_no|
            response = @client.get(list_of_projects_endpoint, { page: (page_no + 1), page_size: PAGE_SIZE })
            status, body = Utils::parse_response(response)
            print_list_of_projects(body, (page_no + 1))      
          end
        end
      end
    end

    def print_list_of_projects(body, page_no)
      if body.is_a?(Array)
        body.each_with_index do |project, i|
          idx = (((page_no-1) * PAGE_SIZE) + i + 1).to_s.rjust(3, ' ')
          puts " ==> [#{idx}] #{Paint[project["name"], :cyan]}, created: #{Paint[project["creation_time"], :yellow]}, id: #{Paint[project["project_id"], :green]}, repos: #{Paint[project["repo_count"], :green]}"
        end
      end
    end

  end

end

=begin

GET repositories:

curl -X GET "https://registry.datalite.cz/api/v2.0/projects/tsm-cetin-release/repositories?page=1&page_size=10"
  -H  "accept: application/json"
  -H  "authorization: Basic ..."

response:
  x-total-count: 41

GET projects:


=end

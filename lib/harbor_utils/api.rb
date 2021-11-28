module HarborUtils

  require "awesome_print"
  require "paint"
  require_relative "client"
  require_relative "utils"
  require_relative "project"
  require_relative "repository"

  PAGE_SIZE = 10
  class Api

    attr_reader :projects

    def initialize(url, user, pass, project_name, keep_images, keep_days)
      @client = HarborUtils::Client.new(url, user, pass)
      @project_name = project_name
      @keep_images = keep_images
      @keep_days = keep_days
      @api_path = "api/v2.0"
      @projects = {}
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

    def list_of_repositories_endpoint(project_name)
      "#{@api_path}/projects/#{project_name}/repositories"
    end

    def healthy?(status)
      status.downcase.start_with?("health")
    end

    def call(what)
      case what
      when :health
        api_health()
      when :projects
        api_projects()
        print_projects()
      when :repositories
        api_projects()
        api_repositories(@project_name)
        print_repositories(@project_name)
      when :info
        call_info()
      when :cleanup
        call_cleanup()
      when :artifacts
        call_artifacts()
      end
    end

    private

    def api_health
      response = @client.get(health_endpoint)
      status, body = Utils::parse_response(response)
      if @client.ok?(status)
        if healthy?(body["status"])
          puts "Harbor is #{Paint["healthy!", :green]}"
        else
          puts "Harbor is #{Paint["unhealthy!", :red]}"
        end
        print_health_of_components(body)
      end
    end

    def print_health_of_components(body)
      if body.has_key? "components"
        puts "Status of each component:"
        body["components"].each do |component|
          print_component_health(component["name"], component["status"])
        end
      end
    end

    def print_component_health(name, status)
      if healthy?(status)
        puts "#{Paint[name, :cyan]} is #{Paint["healthy!", :green]}"
      else
        puts "#{Paint[name, :cyan]} is #{Paint["unhealthy!", :red]}"
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

    def api_projects
      @projects = {}
      response = @client.get(list_of_projects_endpoint, { page_size: PAGE_SIZE })
      status, body = Utils::parse_response(response)
      if @client.ok?(status)
        api_projects_page(body, 1)
        cnt = total_count(response)
        if cnt > 0
          1.upto(cnt) do |page_no|
            response = @client.get(list_of_projects_endpoint, { page: (page_no + 1), page_size: PAGE_SIZE })
            status, body = Utils::parse_response(response)
            api_projects_page(body, (page_no + 1))
          end
        end
      end
    end

    def print_projects
      puts "Number of projects: #{Paint[@projects.size, :green]}"
      projects = @projects.sort_by { |(k, v)| v.id }
      projects.each do |name, project|
        puts project
      end
    end

    def api_projects_page(body, page_no)
      if body.is_a?(Array)
        body.each_with_index do |project, i|
          @projects[project["name"]] = Project.new(project["project_id"], project["name"], project["creation_time"], project["repo_count"])
        end
      end
    end

    def api_repositories(project_name)
      if @projects.has_key? project_name
        repos = {}
        response = @client.get(list_of_repositories_endpoint(project_name), { page_size: PAGE_SIZE })
        status, body = Utils::parse_response(response)
        if @client.ok?(status)
          api_list_of_repositories(body, 1, repos)
          cnt = total_count(response)
          if cnt > 0
            1.upto(cnt) do |page_no|
              response = @client.get(list_of_repositories_endpoint(project_name), { page: (page_no + 1), page_size: PAGE_SIZE })
              status, body = Utils::parse_response(response)
              api_list_of_repositories(body, (page_no + 1), repos)
            end
          end
        end
        @projects[project_name].repositories = repos
      else
        puts "Project with name #{Paint[project_name, :cyan]} does not exists!"
      end
    end

    def api_list_of_repositories(body, page_no, repos)
      if body.is_a?(Array)
        body.each_with_index do |repository, i|
          repos[repository["name"]] = Repository.new(repository["id"], repository["name"], repository["creation_time"], repository["artifact_count"])
        end
      end
    end

    def print_repositories(project_name)
      if @projects.has_key? project_name
        repos = @projects[project_name].repositories.sort_by { |(k, v)| v.id }
        puts "Project with name: #{Paint[project_name, :cyan]}"
        puts "Number of repositories: #{Paint[repos.size, :green]}"
        repos.each do |name, repo|
          puts repo
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

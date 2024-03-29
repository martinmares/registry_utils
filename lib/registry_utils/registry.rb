module RegistryUtils
  require "awesome_print"
  require "paint"
  require "highline/import"
  require "benchmark"
  require_relative "client"
  require_relative "utils"
  require_relative "project"
  require_relative "repository"
  require_relative "artifact"
  require_relative "snap_loader"
  require_relative "docker_transfer"

  PAGE_SIZE = 10

  class Registry
    attr_reader :projects

    def initialize(args)
      @args = args
      @url = @args[:url]
      @client = RegistryUtils::Client.new(@url, @args[:user], @args[:pass], @args[:lines_only])
      @project_name = @args[:project]
      @repository_name = @args[:repository]
      @keep_last_n = @args[:keep_last_n]
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

    def list_of_repositories_endpoint(project_name, repository_name = nil)
      if repository_name
        repo = repository_name.gsub("/", "%252F")
        "#{@api_path}/projects/#{project_name}/repositories/#{repo}"
      else
        "#{@api_path}/projects/#{project_name}/repositories"
      end
    end

    def list_of_artifacts_endpoint(project_name, repository_name)
      repo = repository_name.gsub("/", "%252F")
      "#{@api_path}/projects/#{project_name}/repositories/#{repo}/artifacts"
    end

    def delete_artifact(project_name, repository_name, digest)
      repo = repository_name.gsub("/", "%252F")
      reference = digest.gsub(":", "%3A")
      "#{@api_path}/projects/#{project_name}/repositories/#{repo}/artifacts/#{reference}"
    end

    def healthy?(status)
      status.downcase.start_with?("health")
    end

    def call(what)
      case what
      when :health
        api_health()
        print_health()
      when :projects
        api_projects()
        print_projects()
      when :repositories
        api_projects()
        api_repositories(@project_name, @repository_name)
        print_repositories(@project_name, @repository_name)
      when :cleanup
        api_projects()
        api_repositories(@project_name, @repository_name)
        if Utils::blank? @repository_name
          confirm = ask("No repository is defined, so it must be explicitly acknowledged.\nThe delete operation applies to all repositories in the project!.\nDo you really want to run it? [Y/N] ") { |yn| yn.limit = 1, yn.validate = /[yn]/i }
          if confirm.downcase[0] == "y"
            @projects[@project_name].repositories.each do |name, repo|
              api_artifacts(@project_name, repo.name)
              api_cleanup(@project_name, repo.name)
            end
          else
            puts "Nothing to do."
          end
        else
          api_artifacts(@project_name, @repository_name)
          api_cleanup(@project_name, @repository_name)
        end
      when :artifacts
        api_projects()
        api_repositories(@project_name, @repository_name)
        if @repository_name
          api_artifacts(@project_name, @repository_name)
          print_artifacts(@project_name, @repository_name)
        else
          if @projects.has_key?(@project_name)
            @projects[@project_name].repositories.each do |(repo_name, _data)|
              api_artifacts(@project_name, repo_name)
              print_artifacts(@project_name, repo_name)
            end
          end
        end
      when :snapshot
        bundle_name = @args[:bundle]
        puts "Bundle name #{Paint[bundle_name, :yellow]}"
        api_projects()

        SnapLoader::with_config(bundle_name) do |config|
          puts "Bundles:"
          completed = true
          config.each_bundles_with_index do |bundle, i|
            puts "  [#{Paint[(i + 1).to_s.rjust(2, " "), :green]}] #{Paint[bundle.name, :magenta]} (project: #{Paint[bundle.project, :yellow]})"
            bundle.each_repos_with_index do |repo, i|
              rename_to = ", rename_to: #{Paint[repo.rename_to, :blue]}" if repo.rename_to
              keep_tag_as_is = ", keep_tag_as_is: #{Paint[repo.keep_tag_as_is, :cyan]}" if repo.keep_tag_as_is
              puts "       [#{Paint[(i + 1).to_s.rjust(2, " "), :green]}] #{repo.name} (tag: #{Paint[repo.tag, :blue]}#{rename_to}#{keep_tag_as_is})"
              api_repositories(bundle.project, repo.name)
              api_artifacts(bundle.project, repo.name)
              # print_artifacts(bundle.project, repo.name)
              detected = detect_artifact_with_tag(bundle.project, repo.name, repo.tag)
              repo.add_image_url(@url, bundle.project, repo.name)
              if detected
                puts "            => #{Paint[detected.digest, :green]}"
                repo.detected(true)
                repo.add_detected_digest(detected.digest)
                repo.add_rename_to(repo.rename_to) if repo.rename_to
              else
                msg = "There is no artifact with tag name \"#{repo.tag}\"!"
                puts "            => #{Paint[msg, :red]}"
                repo.detected(false)
                completed = false
              end
            end
          end
          config.completed(completed)
          config.save(@args)
        end
      when :transfer
        # ./bin/registry_utils transfer
        #    from ==>   -l $HARBOR_URL -u $HARBOR_USER -e $HARBOR_PASS -b tsm-cetin-release -s latest
        #    to   ==>   -t $HARBOR_URL -n $HARBOR_USER -w $HARBOR_PASS -p tsm-cetin-release
        DockerTransfer::open_with(@args) do |docker|
          puts "Transfer images ..."
          t = Benchmark.measure { docker.transfer_images() }
          puts "\n"
          puts " ⌛ real time: #{Paint[t.real, :magenta]} sec"
        end
      end
    end

    private

    def api_health
      response = @client.get(health_endpoint)
      status, body = Utils::parse_response(response)
      if @client.ok?(status)
        @health = body
      end
    end

    def print_health
      if healthy?(@health["status"])
        puts "Registry is #{Paint["healthy!", :green]}"
      else
        puts "Registry is #{Paint["unhealthy!", :red]}"
      end
      print_health_of_components(@health)
    end

    def print_health_of_components(health)
      if health.has_key? "components"
        puts "Status of each component:"
        health["components"].each do |component|
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
      else
        puts "Something wrong (api_projects) => status: #{response.status}, body: #{response.body}"
      end
    end

    def print_projects
      if @args[:lines_only]
        projects.each_with_index do |(name, project), i|
          puts "#{name}"
        end
      else
        puts "Number of projects: #{Paint[@projects.size, :green]}"
        projects = @projects.sort_by { |(k, v)| v.id }
        projects.each_with_index do |(name, project), i|
          puts "[#{(i + 1).to_s.rjust(3, " ")}] #{project}"
        end
      end
    end

    def api_projects_page(body, page_no)
      if body.is_a?(Array)
        body.each_with_index do |project, i|
          @projects[project["name"]] = Project.new(project["project_id"], project["name"], project["creation_time"], project["repo_count"])
        end
      end
    end

    def api_repositories(project_name, repository_name = nil)
      if @projects.has_key? project_name
        repos = {}
        response = @client.get(list_of_repositories_endpoint(project_name, repository_name), { page_size: PAGE_SIZE })
        status, body = Utils::parse_response(response)
        if @client.ok?(status)
          api_list_of_repositories(body, 1, project_name, repos)
          cnt = total_count(response)
          if cnt > 0
            1.upto(cnt) do |page_no|
              response = @client.get(list_of_repositories_endpoint(project_name, repository_name), { page: (page_no + 1), page_size: PAGE_SIZE })
              status, body = Utils::parse_response(response)
              api_list_of_repositories(body, (page_no + 1), project_name, repos)
            end
          end
        else
          puts "Something wrong (api_repositories) => status: #{response.status}, body: #{response.body}"
        end
        @projects[project_name].repositories = repos
      else
        puts "Project with name #{Paint[project_name, :cyan]} does not exists!" unless @args[:lines_only]
      end
    end

    def api_list_of_repositories(body, page_no, project_name, repos)
      if body.is_a?(Array)
        body.each_with_index do |repository, i|
          repo_name = repository["name"].gsub("#{project_name}/", "")
          repo_rename_to = repository["rename_to"]
          repos[repo_name] = Repository.new(repository["id"], repo_name, repo_rename_to, repository["creation_time"], repository["artifact_count"])
        end
      elsif body.is_a?(Hash)
        repository = body
        repo_name = repository["name"].gsub("#{project_name}/", "")
        repo_rename_to = repository["rename_to"]
        repos[repo_name] = Repository.new(repository["id"], repo_name, repo_rename_to, repository["creation_time"], repository["artifact_count"])
      end
    end

    def print_repositories(project_name, repository_name = nil)
      if @projects.has_key? project_name
        repos = @projects[project_name].repositories.sort_by { |(k, v)| v.id }
        puts "Project with name: #{Paint[project_name, :cyan]}" unless @args[:lines_only]
        puts "Number of repositories: #{Paint[repos.size, :green]}" unless @args[:lines_only]
        if @args[:lines_only]
          repos.each_with_index do |(name, repo), i|
            puts "#{name}"
          end
        else
          repos.each_with_index do |(name, repo), i|
            puts "[#{(i + 1).to_s.rjust(3, " ")}] #{repo}"
          end
        end
      end
    end

    def api_artifacts(project_name, repository_name)
      artifacts = {}
      if @projects.has_key? project_name
        project = @projects[project_name]
        repos = project.repositories

        if repos.has_key? repository_name
          response = @client.get(list_of_artifacts_endpoint(project_name, repository_name), { page_size: PAGE_SIZE, with_tag: true, with_signatures: true })
          status, body = Utils::parse_response(response)
          if @client.ok?(status)
            api_list_of_artifacts(body, 1, project_name, repository_name, artifacts)
            cnt = total_count(response)
            if cnt > 0
              1.upto(cnt) do |page_no|
                response = @client.get(list_of_artifacts_endpoint(project_name, repository_name), { page: (page_no + 1), page_size: PAGE_SIZE, with_tag: true, with_signatures: true })
                status, body = Utils::parse_response(response)
                api_list_of_artifacts(body, (page_no + 1), project_name, repository_name, artifacts)
              end
            end
          else
            puts "Something wrong (api_artifacts) => status: #{response.status}, body: #{response.body}"
          end

          repos[repository_name].artifacts = artifacts
        else
          puts "Repo with name #{Paint[repository_name, :cyan]} not found!"
        end
      end
    end

    def api_list_of_artifacts(body, page_no, project_name, repository_name, artifacts)
      if body.is_a?(Array)
        body.each_with_index do |artifact, i|
          artifacts[artifact["id"].to_i] = Artifact.new(artifact["id"], artifact["digest"], artifact["push_time"], artifact["pull_time"], artifact["size"], artifact["tags"])
        end
      end
    end

    def print_artifacts(project_name, repository_name)
      if @projects.has_key? project_name
        project = @projects[project_name]
        repos = project.repositories

        if repos.has_key?(repository_name) && repos[repository_name].artifacts
          search_by_tag = @args[:search_by_tag]
          artifacts = repos[repository_name].artifacts.sort_by { |(k, v)| v.id }
          if search_by_tag
            filtered_artifacts = artifacts.filter { |(id, artifact)| artifact.tags.filter { |tag| tag[search_by_tag] }.size > 0 }
          else
            filtered_artifacts = artifacts
          end
          if filtered_artifacts && filtered_artifacts.size > 0
            puts "Repo with name #{Paint[repository_name, :cyan]}"
            puts "Found #{Paint[filtered_artifacts.size, :green]} artifacts"
            puts "Search by tag #{Paint[search_by_tag, :yellow]}" if search_by_tag
            filtered_artifacts.each_with_index do |(id, artifact), i|
              unless search_by_tag
                puts "[#{(i + 1).to_s.rjust(3, " ")}] #{artifact}"
              else
                puts "[#{(i + 1).to_s.rjust(3, " ")}] #{artifact.to_s_higlight(search_by_tag)}"
              end
            end
          end
        end
      end
    end

    def detect_artifact_with_tag(project_name, repository_name, tag_name)
      if @projects.has_key? project_name
        project = @projects[project_name]
        repos = project.repositories

        if repos.has_key? repository_name
          artifacts = repos[repository_name].artifacts.sort { |(ka, va), (kb, vb)| vb.id <=> va.id } # sort descending
          artifacts.each_with_index do |(id, artifact), i|
            return artifact if (artifact.tags.any? { |t| t == tag_name })
          end
        end
      end
      nil
    end

    def api_cleanup(project_name, repository_name)
      if @projects.has_key? project_name
        project = @projects[project_name]
        repos = project.repositories

        if repos.has_key? repository_name
          artifacts = repos[repository_name].artifacts.sort_by { |(k, v)| v.id }
          puts "Project with name: #{Paint[project_name, :cyan]}"
          puts "Repo with name: #{Paint[repository_name, :cyan]}"
          puts "Number of artifacts: #{Paint[artifacts.size, :green]}"
          keep_ids = artifacts.map { |id, artifact| artifact.id }.to_a.sort { |a, b| b <=> a }.take(@keep_last_n)
          keep = {}
          keep_ids.each do |id|
            keep[id] = id
          end

          artifacts.each_with_index do |(id, artifact), i|
            if keep.has_key?(id)
              puts "[#{(i + 1).to_s.rjust(3, " ")}] #{Paint["KEEP  ", :green]} #{artifact}"
            else
              unless @args[:dry_run]
                puts "[#{(i + 1).to_s.rjust(3, " ")}] #{Paint["DELETE", :red]} #{artifact}"
                response = @client.delete(delete_artifact(project_name, repository_name, artifact.digest))
                if @client.ok?(response.status)
                  puts "      => artifact #{Paint[artifact.digest, :green]} successfully deleted!"
                else
                  puts "Something wrong (api_cleanup) => status: #{response.status}, body: #{response.body}"
                end
              else
                puts "[#{(i + 1).to_s.rjust(3, " ")}] #{Paint["DELETE!", :magenta]} #{artifact} #{Paint["(dry run only)!", :yellow]}"
              end
            end
          end
        end
      end
    end
  end
end

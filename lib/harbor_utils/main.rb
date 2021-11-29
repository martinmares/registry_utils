module HarborUtils

  class Main

    attr_reader :args, :command

    require "optimist"
    require "paint"
    
    require_relative "api"

    CMD_HEALTH = "health"
    CMD_PROJECTS = "projects"
    CMD_REPOSITORIES = "repositories"
    CMD_ARTIFACTS = "artifacts"
    CMD_CLEANUP = "cleanup"

    SUB_COMMANDS = [CMD_CLEANUP, CMD_PROJECTS, CMD_HEALTH, CMD_REPOSITORIES, CMD_ARTIFACTS]

    def initialize()
      @command, @global_args, @args = parse_args()
      @api = Api.new(@args[:url], @args[:user], @args[:pass], @args[:project_name], @args[:repository_name], @args[:keep_last_n])
      puts "Running command #{Paint[@command, :yellow]} ..."
    end

    def health
      @client.get(health_path)
    end

    def cmd_health?
      @command == CMD_HEALTH
    end

    def cmd_projects?
      @command == CMD_PROJECTS
    end

    def cmd_cleanup?
      @command == CMD_CLEANUP
    end

    def cmd_repositories?
      @command == CMD_REPOSITORIES
    end

    def cmd_artifacts?
      @command == CMD_ARTIFACTS
    end

    def run
      if cmd_health?
        @api.call(:health)
      elsif cmd_projects?
        @api.call(:projects)
      elsif cmd_cleanup?
        @api.call(:cleanup)
      elsif cmd_repositories?
        @api.call(:repositories)
      elsif cmd_artifacts?
        @api.call(:artifacts)
      end
    end

    private

    def parse_args
      global_opts = Optimist::options do
        banner "Harbor utility, possible commands are: #{SUB_COMMANDS}"
        opt :debug, "Debug?", type: :boolean, default: false
        stop_on SUB_COMMANDS
      end

      subcommand = ARGV.shift
      opts = case subcommand
        when "cleanup"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-u"
            opt :user, "User name", type: :string, required: true, short: "-s"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project_name, "Project name", type: :string, required: true, short: "-p"
            opt :repository_name, "Repository name", type: :string, required: false, short: "-r"
            opt :keep_last_n, "Keep last `n` of images", type: :integer, required: true, short: "-k"
          end
        when "projects"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-u"
            opt :user, "User name", type: :string, required: true, short: "-s"
            opt :pass, "Password", type: :string, required: true, short: "-e"
          end
        when "repositories"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-u"
            opt :user, "User name", type: :string, required: true, short: "-s"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project_name, "Project name", type: :string, required: true, short: "-p"
            opt :repository_name, "Repository name", type: :string, required: false, short: "-r"
          end
        when "artifacts"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-u"
            opt :user, "User name", type: :string, required: true, short: "-s"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project_name, "Project name", type: :string, required: true, short: "-p"
            opt :repository_name, "Repository name", type: :string, required: false, short: "-r"
          end
        when "health"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-u"
            opt :user, "User name", type: :string, required: true, short: "-s"
            opt :pass, "Password", type: :string, required: true, short: "-e"
          end
        else
          Optimist::die "unknown subcommand #{subcommand.inspect}"
        end

        [subcommand, global_opts, opts]

    end

  end

end

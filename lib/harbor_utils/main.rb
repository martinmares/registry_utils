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
    CMD_INFO = "info"
    CMD_CLEANUP = "cleanup"

    SUB_COMMANDS = [CMD_CLEANUP, CMD_PROJECTS, CMD_INFO, CMD_HEALTH, CMD_REPOSITORIES, CMD_ARTIFACTS]

    def initialize()
      @command, @global_args, @args = parse_args()
      @api = Api.new(@args[:url], @args[:user], @args[:pass], @args[:project_name], @args[:repository_name], @args[:keep_images], @args[:keep_days])
      puts "Running command #{Paint[@command, :yellow]}..."
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

    def cmd_info?
      @command == CMD_INFO
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
      elsif cmd_info?
        @api.call(:info)
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
            opt :all_repos, "If specifily `all-repos=true`, cleanup rule will be applied on all repos for this project", type: :boolean, require: false, short: "-a"
            opt :keep_images, "Keep last `i` images", type: :integer, required: false, short: "-i"
            opt :keep_days, "Keep only images created before today-`d` days", type: :integer, required: false, short: "-d"
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
        when "info"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-u"
            opt :user, "User name", type: :string, required: true, short: "-s"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project_name, "Project name", type: :string, required: true, short: "-p"
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

=begin
        global_opts = Optimist::options do
          banner "Harbor utility, can show Harbor `health` or some project `stats` or `cleanup` resources (containers)."
          opt :debug, "Debug?", type: :boolean, default: false  
          stop_on SUB_COMMANDS
        end

        cmd = ARGV.shift # get the subcommand
        cmd_opts = case cmd
          when "delete" # parse delete options
            Optimist::options do
              opt :force, "Force deletion"
              opt :url, "Harbor URL", type: :string, required: true #, short: "-u"
              opt :user_name, "User name", type: :string, required: true #, short: "-s"
              opt :user_pass, "User password", type: :string, required: true #, short: "-e"
                end
          when "copy"  # parse copy options
            Optimist::options do
              opt :double, "Copy twice for safety's sake"
              opt :url, "Harbor URL", type: :string, required: true #, short: "-u"
              opt :user_name, "User name", type: :string, required: true #, short: "-s"
              opt :user_pass, "User password", type: :string, required: true #, short: "-e"
                end
          else
            Optimist::die "unknown subcommand #{cmd.inspect}"
          end
=end

    end

  end

end

module RegistryUtils
  class Main

    attr_reader :args, :command

    require "optimist"
    require "paint"

    require_relative "harbor"

    CMD_HEALTH = "health"
    CMD_PROJECTS = "projects"
    CMD_REPOSITORIES = "repositories"
    CMD_ARTIFACTS = "artifacts"
    CMD_CLEANUP = "cleanup"
    CMD_SNAPSHOT = "snapshot"
    CMD_TRANSFER = "transfer"

    SUB_COMMANDS = [CMD_CLEANUP, CMD_PROJECTS, CMD_HEALTH, CMD_REPOSITORIES, CMD_ARTIFACTS, CMD_SNAPSHOT, CMD_TRANSFER]

    def initialize()
      @command, @global_args, @args = parse_args()
      @harbor = Harbor.new(@args)
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

    def cmd_snapshot?
      @command == CMD_SNAPSHOT
    end

    def cmd_transfer?
      @command == CMD_TRANSFER
    end

    def run
      if cmd_health?
        @harbor.call(:health)
      elsif cmd_projects?
        @harbor.call(:projects)
      elsif cmd_cleanup?
        @harbor.call(:cleanup)
      elsif cmd_repositories?
        @harbor.call(:repositories)
      elsif cmd_artifacts?
        @harbor.call(:artifacts)
      elsif cmd_snapshot?
        @harbor.call(:snapshot)
      elsif cmd_transfer?
        @harbor.call(:transfer)
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
            opt :url, "Harbor URL", type: :string, required: true, short: "-l"
            opt :user, "User name", type: :string, required: true, short: "-u"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project, "Project name", type: :string, required: true, short: "-p"
            opt :repository, "Repository name", type: :string, required: false, short: "-r"
            opt :keep_last_n, "Keep last `n` of images", type: :integer, required: true, short: "-k"
          end
        when "projects"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-l"
            opt :user, "User name", type: :string, required: true, short: "-u"
            opt :pass, "Password", type: :string, required: true, short: "-e"
          end
        when "repositories"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-l"
            opt :user, "User name", type: :string, required: true, short: "-u"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project, "Project name", type: :string, required: true, short: "-p"
            opt :repository, "Repository name", type: :string, required: false, short: "-r"
          end
        when "artifacts"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-l"
            opt :user, "User name", type: :string, required: true, short: "-u"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project, "Project name", type: :string, required: true, short: "-p"
            opt :repository, "Repository name", type: :string, required: false, short: "-r"
          end
        when "health"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-l"
            opt :user, "User name", type: :string, required: true, short: "-u"
            opt :pass, "Password", type: :string, required: true, short: "-e"
          end
        when "snapshot"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-l"
            opt :user, "User name", type: :string, required: true, short: "-u"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :bundle, "Bundle name (must be located here: `conf/bundle.{bundle-name}.yml`)", type: :string, required: true, short: "-b"
            opt :patch_snapshot_id, "Patch snapshot ID (contains images with sha256 digests)", type: :string, required: false, short: "-s"
            opt :patch_repositories, "Patch only repositories (comma separated list)", type: :string, require: false, short: "-o"
          end
        when "transfer"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-l"
            opt :user, "User name", type: :string, required: true, short: "-u"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :bundle, "Bundle name", type: :string, required: true, short: "-b"
            opt :snapshot_id, "Snapshot version (contains images with sha256 digests)", type: :string, required: true, short: "-s"
            opt :download_by, "Download source images by \"tag\" or by \"sha256\" digests", type: :string, required: true, short: "-y"
            opt :target_url, "Harbor URL (target)", type: :string, required: true, short: "-t"
            opt :target_user, "User name (target)", type: :string, required: true, short: "-n"
            opt :target_pass, "Password (target)", type: :string, required: true, short: "-w"
            opt :target_bundle, "Virtual bundle name (created from an existing snapshot)", type: :string, required: true, short: "-r"
            opt :target_project, "Project name (target)", type: :string, required: true, short: "-p"
            opt :docker_api, "Docker URL (TCP: 'tcp://example.com:5422' or SOCKET: 'unix:///var/run/docker.sock')", type: :string, required: true, short: "-d"
            opt :docker_fake, "Fake only Docker API?", type: :boolean, default: false, required: false, short: "-o"
            opt :add_tag, "Add tag (for example 'target')", type: :string, required: false, short: "-a"
          end
        else
          Optimist::die "unknown subcommand #{subcommand.inspect}"
        end

        [subcommand, global_opts, opts]

    end

  end

end

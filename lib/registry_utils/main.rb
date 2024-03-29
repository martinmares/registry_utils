module RegistryUtils
  class Main
    attr_reader :args, :command

    require "optimist"
    require "paint"

    require_relative "registry"

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
      @registry = Registry.new(@args)
      puts "Running command #{Paint[@command, :yellow]} ..." unless @args[:lines_only]
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
        @registry.call(:health)
      elsif cmd_projects?
        @registry.call(:projects)
      elsif cmd_cleanup?
        @registry.call(:cleanup)
      elsif cmd_repositories?
        @registry.call(:repositories)
      elsif cmd_artifacts?
        @registry.call(:artifacts)
      elsif cmd_snapshot?
        @registry.call(:snapshot)
      elsif cmd_transfer?
        @registry.call(:transfer)
      end
    end

    private

    def parse_args
      global_opts = Optimist::options do
        banner "Registry utility (Harbor), possible commands are: #{SUB_COMMANDS}"
        opt :debug, "Debug?", type: :boolean, default: false
        stop_on SUB_COMMANDS
      end

      subcommand = ARGV.shift

      basic_opts = [
        { name: :url, desc: "Registry URL", opts: { type: :string, required: true, short: "-l" } },
        { name: :user, desc: "User name", opts: { type: :string, required: true, short: "-u" } },
        { name: :pass, desc: "Password", opts: { type: :string, required: true, short: "-e" } },
        { name: :lines_only, desc: "Simple lines (text only) output", opts: { type: :boolean, required: false, default: false, short: "-i" } },
      ]

      opts = case subcommand
        when CMD_CLEANUP
          Optimist::options do
            basic_opts.each { |e| opt e[:name], e[:desc], e[:opts] }
            opt :project, "Project name", type: :string, required: true, short: "-p"
            opt :repository, "Repository name", type: :string, required: false, short: "-r"
            opt :keep_last_n, "Keep last `n` of images", type: :integer, required: true, short: "-k"
            opt :dry_run, "Dry run? (fake only)", type: :boolean, default: false, required: false, short: "-f"
          end
        when CMD_PROJECTS
          Optimist::options do
            basic_opts.each { |e| opt e[:name], e[:desc], e[:opts] }
          end
        when CMD_REPOSITORIES
          Optimist::options do
            basic_opts.each { |e| opt e[:name], e[:desc], e[:opts] }
            opt :project, "Project name", type: :string, required: true, short: "-p"
            opt :repository, "Repository name", type: :string, required: false, short: "-r"
          end
        when CMD_ARTIFACTS
          Optimist::options do
            basic_opts.each { |e| opt e[:name], e[:desc], e[:opts] }
            opt :project, "Project name", type: :string, required: true, short: "-p"
            opt :repository, "Repository name", type: :string, required: false, short: "-r"
            opt :search_by_tag, "Search by 'tag'", type: :string, required: false, short: "-g"
          end
        when CMD_HEALTH
          Optimist::options do
            basic_opts.each { |e| opt e[:name], e[:desc], e[:opts] }
          end
        when CMD_SNAPSHOT
          Optimist::options do
            basic_opts.each { |e| opt e[:name], e[:desc], e[:opts] }
            opt :bundle, "Bundle name (must be located here: `conf/bundle.{bundle-name}.yml`)", type: :string, required: true, short: "-b"
            opt :patch_snapshot_id, "Patch snapshot ID (contains images with sha256 digests)", type: :string, required: false, short: "-s"
            opt :patch_repository, "Patch only repository, can be #{Paint["multi", :green]} -p image1 -p image2", type: :string, require: false, short: "-p"
          end
        when CMD_TRANSFER
          Optimist::options do
            basic_opts.each { |e| opt e[:name], e[:desc], e[:opts] }
            opt :bundle, "Bundle name", type: :string, required: true, short: "-b"
            opt :snapshot_id, "Snapshot version (contains images with sha256 digests)", type: :string, required: true, short: "-s"
            opt :pull_by, "Pull source images by 'tag' or by 'sha256' digest", type: :string, required: true, short: "-y"
            opt :patch_only, "Transfer patch only repositories?", type: :boolean, required: false, default: false, short: "-h"
            opt :save_as, "Save with name (instead of original snapshot_id)", type: :string, required: false, short: "-o"
            opt :target_url, "Registry URL (target)", type: :string, required: true, short: "-t"
            opt :target_user, "User name (target)", type: :string, required: true, short: "-n"
            opt :target_pass, "Password (target)", type: :string, required: true, short: "-w"
            opt :target_bundle, "Virtual bundle name (created from an existing snapshot)", type: :string, required: true, short: "-r"
            opt :target_project, "Project name (target)", type: :string, required: true, short: "-p"
            opt :docker_api, "Docker URL (TCP: 'tcp://example.com:5422' or SOCKET: 'unix:///var/run/docker.sock')", type: :string, required: true, short: "-d"
            opt :dry_run, "Dry run? (fake only Docker API)", type: :boolean, default: false, required: false, short: "-f"
            opt :add_tag, "Add tag (can be #{Paint["multi", :green]}, for example -a 'latest' -a 'RE29.SP1' -a '2022.16.0')", type: :string, required: false, short: "-a", multi: true
          end
        else
          Optimist::die "unknown subcommand #{subcommand.inspect}"
        end

      [subcommand, global_opts, opts]
    end
  end
end

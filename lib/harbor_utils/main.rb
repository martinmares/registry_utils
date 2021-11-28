module HarborUtils

  class Main

    attr_reader :args, :command

    require "optimist"
    require "paint"
    
    require_relative "api"

    CMD_HEALTH = "health"
    CMD_STATS = "stats"
    CMD_CLEANUP = "cleanup"

    SUB_COMMANDS = [CMD_CLEANUP, CMD_STATS, CMD_HEALTH]

    def initialize()
      @command, @global_args, @args = parse_args()
      @api = Api.new(@args[:url], @args[:user], @args[:password], @args[:project_name], @args[:keep_images], @args[:keep_days])
      puts "Running command #{Paint[@command, :yellow]}..."
    end

    def health
      @client.get(health_path)
    end

    def cmd_health?
      @command == CMD_HEALTH
    end

    def cmd_stats?
      @command == CMD_STATS
    end

    def cmd_cleanup?
      @command == CMD_CLEANUP
    end

    def run
      if cmd_health?
        @api.call(:health)
      elsif cmd_stats?
        @api.call(:stats)
      end
    end

    private

    def parse_args
      global_opts = Optimist::options do
        banner "Harbor utility, possible commands are: `health`, `stats`, `cleanup`"
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
            opt :keep_images, "Keep last `i` images", type: :integer, required: false, short: "-i"
            opt :keep_days, "Keep only images created before today-`d` days", type: :integer, required: false, short: "-d"
          end
        when "stats"
          Optimist::options do
            opt :url, "Harbor URL", type: :string, required: true, short: "-u"
            opt :user, "User name", type: :string, required: true, short: "-s"
            opt :pass, "Password", type: :string, required: true, short: "-e"
            opt :project_name, "Project name", type: :string, required: false, short: "-p"
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

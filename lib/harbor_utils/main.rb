module HarborUtils

  class Main

    attr_reader :args

    require "optimist"
    require "awesome_print"

    SUB_COMMANDS = %w(cleanup health stats)

    def initialize()
      @args = parse_args()
    end

    private

    def parse_args

      global_opts = Optimist::options do
        banner "Harbor utility, show `health` or `cleanup` containers"
        stop_on SUB_COMMANDS
      end

      subcommand = ARGV.shift
      opts = case subcommand
        when "cleanup"
          Optimist::options do
            opt :uri_api, "Harbor API URI", type: :string, required: true, short: "-u"
            opt :project_name, "Project name", type: :string, required: true, short: "-p"
            opt :keep_images, "Keep last `i` images", type: :integer, required: false, short: "-i"
            opt :keep_days, "Keep only images created before today-`d` days", type: :integer, required: false, short: "-d"
            opt :debug, "Debug?", type: :boolean, default: false
          end
        when "health"
          Optimist::options do
            opt :uri_api, "Harbor API URI", type: :string, required: true, short: "-u"
          end
        when "stats"
          Optimist::options do
            opt :uri_api, "Harbor API URI", type: :string, required: true, short: "-u"
            opt :project_name, "Project name", type: :string, required: true, short: "-p"
          end
        else
          Optimist::die "unknown subcommand #{subcommand.inspect}"
        end
      opts

    end

  end

end

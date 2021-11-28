module HarborUtils

  class Project

    attr_accessor :id, :name, :created, :repo_count, :repositories

    def initialize(id, name, created, repo_count)
      @id = id
      @name = name
      @created = DateTime.parse(created)
      @repo_count = repo_count
      @repositories = {}
    end

    def to_s
      time_ago = Utils.new().time_ago(@created)
      dt_simple = Utils::date_time_simple(@created)
      "id = #{@id.to_s.rjust(3, ' ')}, name = #{Paint[@name, :cyan]}, created = #{dt_simple}, repos = #{Paint[@repo_count, :green]}"
    end

  end

end

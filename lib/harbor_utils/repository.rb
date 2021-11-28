module HarborUtils

  class Repository

    attr_accessor :id, :name, :created, :artifact_count, :artifacts

    def initialize(id, name, created, artifact_count)
      @id = id
      @name = name
      @created = DateTime.parse(created)
      @artifact_count = artifact_count
      @artifacts = {}
    end

    def to_s
      time_ago = Utils.new().time_ago(@created)
      dt_simple = Utils::date_time_simple(@created)
      "id = #{@id.to_s.rjust(3, ' ')}, name = #{Paint[@name, :cyan]}, created = #{dt_simple}, artifacts = #{Paint[@artifact_count, :green]}"
    end

  end
  
end

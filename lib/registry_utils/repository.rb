module RegistryUtils

  class Repository

    attr_accessor :id, :name, :rename_to, :created, :artifact_count, :artifacts

    def initialize(id, name, rename_to, created, artifact_count)
      @id = id
      @name = name
      @rename_to = rename_to
      @created = DateTime.parse(created)
      @artifact_count = artifact_count
      @artifacts = {}
    end

    def to_s
      dt_simple = Utils::date_time_simple(@created)
      "id = #{@id.to_s.rjust(3, ' ')}, name = #{Paint[@name, :cyan]}, created = #{dt_simple}, artifacts = #{Paint[@artifact_count, :green]}"
    end

  end
  
end

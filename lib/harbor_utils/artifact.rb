module HarborUtils

  class Artifact

    attr_reader :id, :digest, :push_time, :pull_time, :size

    def initialize(id, digest, push_time, pull_time, size)
      @id = id
      @push_time = DateTime.parse(push_time)
      @pull_time = DateTime.parse(pull_time)
      @digest = digest
      @size = size
    end

    def to_s
      push_time_ago = Utils.new().time_ago(@push_time)
      pull_time_ago = Utils.new().time_ago(@push_time)
      "id = #{@id.to_s.rjust(8, ' ')}, digest = #{Paint[@digest, :cyan]}, push = #{push_time_ago}, pull = #{pull_time_ago}"
    end

  end
  
end

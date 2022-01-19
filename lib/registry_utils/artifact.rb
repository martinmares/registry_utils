module RegistryUtils

  class Artifact

    attr_reader :id, :digest, :push_time, :pull_time, :size, :tags

    def initialize(id, digest, push_time, pull_time, size, tags)
      @id = id
      @push_time = DateTime.parse(push_time)
      @pull_time = DateTime.parse(pull_time)
      @digest = digest
      @size = size
      @tags = parse_tags(tags)
    end

    def to_s
      push_simple = Utils::date_time_simple(@push_time)
      pull_simple = Utils::date_time_simple(@pull_time)
      "id = #{@id.to_s.rjust(8, ' ')}, digest = #{Paint[@digest, :cyan]}, tags = #{@tags}, push = #{push_simple}, pull = #{pull_simple}"
    end

    def to_s_higlight(search_by_tag)
      push_simple = Utils::date_time_simple(@push_time)
      pull_simple = Utils::date_time_simple(@pull_time)
      (tags, tags_higlighted) = @tags.partition { |e| !e[search_by_tag] }
      "id = #{@id.to_s.rjust(8, ' ')}, digest = #{Paint[@digest, :cyan]}, found = #{Paint[tags_higlighted, :yellow]}, others = #{tags}, push = #{push_simple}, pull = #{pull_simple}"
    end

    private

    def parse_tags(tags)
      if tags.is_a?(Array)
        result = []
        tags.each do |tag|
          result << tag["name"]
        end
        return result
      else
        return []
      end
    end

  end
  
end

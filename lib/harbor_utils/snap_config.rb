module HarborUtils

  require "yaml"
  require "awesome_print"

  class SnapConfig
    attr_reader :file_name, :target

    def initialize(file_name)
      @file_name = file_name
      @target = target
      @bundles = []
      parse()
    end

    def each_bundles
      @bundles.each { |bundle| yield bundle }
    end

    def each_bundles_with_index
      @bundles.each_with_index { |bundle, i| yield bundle, i }
    end

    private

    def parse
      @content = YAML.load_file(@file_name)
      @target = @content["target"]
      if @content.has_key? "bundles"
        @content["bundles"].each do |bundle|
          new_bundle = SnapBundle.new(bundle["name"], bundle["project"])
          if bundle.has_key? "repositories"
            bundle["repositories"].each do |repository|
              new_repository = SnapRepository.new(repository["name"], repository["tag"], repository["keep_tag_as_is"])
              new_bundle.add_repository(new_repository)
            end
          end
          @bundles << new_bundle
        end
      end
    end

  end

  class SnapBundle
    attr_reader :name, :project, :repositories

    def initialize(name, project)
      @name = name
      @project = project
      @repositories = []
    end

    def add_repository(repository)
      @repositories << repository  
    end

    def each_repos
      @repositories.each { |repo| yield repo }
    end

    def each_repos_with_index
      @repositories.each_with_index { |repo,i | yield repo, i }
    end
  end

  class SnapRepository
    attr_reader :name, :tag, :keep_tag_as_is

    def initialize(name, tag, keep_tag_as_is)
      @name = name
      @tag = tag
      @keep_tag_as_is = keep_tag_as_is
      @keep_tag_as_is |= false
    end
  end

end

=begin

target: snapshots/cetin
bundles:
  - name: tsm-core
    project: tsm
    repositories:
      - name: tsm-address-management
        tag: develop
      - name: tsm-calendar
        tag: develop
      - name: tsm-gateway
        tag: develop

=end

module HarborUtils

  require "yaml"
  require "awesome_print"
  require "fileutils"
  require "date"

  class SnapConfig
    attr_reader :file_name, :target

    CALENDAR_PATTERN = "%Y.%m.%d"
    LATEST_IMAGES_FILENAME = "latest.images.yml"

    def initialize(file_name)
      @file_name = file_name
      @bundles = []
      @completed = false
      parse()
    end

    def each_bundles
      @bundles.each { |bundle| yield bundle }
    end

    def each_bundles_with_index
      @bundles.each_with_index { |bundle, i| yield bundle, i }
    end

    def save
      puts "\nSaving now:"
      target_dir = "#{@target}/#{@name}"
      if File.directory? target_dir
        puts "  target 📁 #{Paint[target_dir, :green]} exists"
      else
        puts "  created target 📁 #{Paint[target_dir, :red]}"
        FileUtils.mkdir_p target_dir
      end
      
      today = DateTime.now.strftime("#{CALENDAR_PATTERN}")
      patch = find_patch(today, target_dir)
      new_patch = patch + 1

      if patch == -1
        puts "  first patch today 🎂 , party starts now! 🎉🎉🎉 , patch no #{Paint[new_patch, :green]}, for pattern 📅 #{Paint[today, :magenta]}"
      else
        puts "  `hallelujah`, 👏 found patch no #{Paint[patch, :cyan]}, 💪 upgrading to #{Paint[new_patch, :green]}, for pattern 📅 #{Paint[today, :magenta]}"
      end

      if completed?
        save_to = "#{target_dir}/#{today}.#{new_patch}.images.yml"
      else
        save_to = "#{target_dir}/failed/#{today}.#{new_patch}.images.yml"
      end
      
      yaml = make_yaml()
      File.write(save_to, yaml)
      puts "  💾 saved to file #{Paint[save_to, :cyan]}"
      if @completed
        File.write("#{target_dir}/#{LATEST_IMAGES_FILENAME}", yaml)
        puts "  😺 everything is fine, I'm overwriting the contents of #{Paint[LATEST_IMAGES_FILENAME, :green]}"
      else
        puts "  😿 I didn't find some pictures by tag, `Meow`"
      end
    end

    def completed(result)
      @completed = result
    end

    def completed?
      @completed
    end

    private

    def parse
      @content = YAML.load_file(@file_name)
      @target = @content["target"]
      @name = @content["name"]
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

    def make_yaml
      images = []
      each_bundles do |bundle|
        bundle.each_repos do |repos|
          images << { "name" => repos.name,
                      "tag" => repos.tag,
                      "url" => repos.url,
                      "project" => repos.project,
                      "repository" => repos.repository,
                      "digest" => repos.detected_digest,
                      "image_url" => repos.image_url,
                      "detected" => repos.detected? }
        end
      end
      images.to_yaml
    end

    def find_patch(day, target_dir)
      # puts "#{target_dir}/#{day}.*.images.yml"
      # "snapshots/tsm-cetin-sample/2021.12.02.*.images.yml"
      result = -1
      patches = []
      Dir.glob("#{target_dir}/#{day}.*.images.yml").each do |f|
        patch_no = /(\d+).(\d+).(\d+).(\d+).(\w+).yml/.match(File.basename f)[4]
        patches << patch_no.to_i if patch_no
      end
      result = patches.max if patches.size > 0
      result
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
    attr_reader :name, :tag, :keep_tag_as_is, :url, :project, :repository, :detected_digest

    def initialize(name, tag, keep_tag_as_is)
      @name = name
      @tag = tag
      @keep_tag_as_is = keep_tag_as_is
      @keep_tag_as_is |= false
      @detected = false
      @detected_digest = ""
    end

    def add_detected_digest(digest)
      @detected_digest = digest
    end

    def add_image_url(url, project, repository)
      @url = url
      @project = project
      @repository = repository
    end

    def image_url
      "#{@url}/#{@project}/#{@repository}"
    end

    def detected(result)
      @detected = result
    end

    def detected?
      @detected
    end

    def full_image_url
      "#{@image_url}@#{@detected_digest}"
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

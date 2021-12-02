module HarborUtils

  require "yaml"
  require "awesome_print"
  require "fileutils"
  require "date"
  require 'uri'

  class SnapConfig
    attr_reader :file_name, :target

    CALENDAR_PATTERN = "%Y.%m.%d"
    IMAGES_EXTENSION = "images.yml"
    LATEST_IMAGES_FILENAME = "latest.#{IMAGES_EXTENSION}"
    SNAPSHOTS_DIR = "snapshots"
    FAILED_SNAPSHOTS_SUBDIR = "failed"

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

      if completed?
        target_dir = "#{@target}/#{@name}"
      else
        target_dir = "#{@target}/#{@name}/#{FAILED_SNAPSHOTS_SUBDIR}"
      end

      dt = DateTime.now
      today = dt.strftime("#{CALENDAR_PATTERN}")
      patch = find_patch(today, target_dir)
      new_patch = patch + 1
      check_dir "#{target_dir}"
      save_to = "#{target_dir}/#{today}.#{new_patch}.images.yml"

      if first_patch_today?(patch)
        puts "  first patch today 🎂 , party starts now! 🎉🎉🎉 , patch no #{Paint[new_patch, :green]}, for pattern 📅 #{Paint[today, :magenta]}"
      else
        puts "  `hallelujah`, 👏 found patch no #{Paint[patch, :cyan]}, 💪 upgrading to #{Paint[new_patch, :green]}, for pattern 📅 #{Paint[today, :magenta]}"
      end

      yaml = make_yaml("#{today}.#{new_patch}")
      File.write(save_to, yaml)
      puts "  💾 saved to file #{Paint[save_to, :cyan]}"

      if completed?
        File.write("#{target_dir}/#{LATEST_IMAGES_FILENAME}", yaml)
        puts "  ✅  Everything is fine, I'm overwriting the contents of #{Paint[LATEST_IMAGES_FILENAME, :green]}, `meow` 😺"
        meow()
      else
        puts "  ❌  I'm crying, #{Paint['didn\'t find', :red]} some images by tag, `meow` 😿"
        mouse()
      end

    end

    def completed(result)
      @completed = result
    end

    def completed?
      @completed
    end

    private

    def first_patch_today?(patch)
      patch == -1
    end

    def meow
      puts "\n"
      puts "  /\\_/\\"
      puts " ( o.o )"
      puts "  > ^ <"
    end

    def mouse
      puts "\n"
      puts "  __QQ"
      puts "  (_)_\">"
      puts " _)"
    end

    def parse
      @content = YAML.load_file(@file_name)
      @target = SNAPSHOTS_DIR
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

    def make_yaml(snapshot_id)
      images = []
      each_bundles do |bundle|
        bundle.each_repos do |repos|
          uri = URI("#{repos.image_url}")
          images << { "name" => repos.name,
                      "tag" => repos.tag,
                      "host" => uri.host,
                      "port" => uri.port,
                      "scheme" => uri.scheme,
                      "project" => repos.project,
                      "repository" => repos.repository,
                      "digest" => repos.detected_digest,
                      "detected" => repos.detected? }
        end
      end
      { "timestamp" => DateTime.now.to_s,
        "utc" => DateTime.now.new_offset(0).to_s,
        "snapshot_id" => snapshot_id,
        "images" => images}.to_yaml
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

    def check_dir(dir_name)
      if File.directory? dir_name
        puts "  target 📁 #{Paint[dir_name, :green]} exists"
      else
        puts "  created target 📁 #{Paint[dir_name, :red]}"
        FileUtils.mkdir_p dir_name
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

module RegistryUtils

  require "yaml"
  require "awesome_print"
  require "fileutils"
  require "date"
  require 'uri'
  require_relative "snap_snapshot"

  class SnapConfig
    attr_reader :file_name, :target, :bundles

    CALENDAR_PATTERN = "%Y.%m.%d"
    IMAGES_EXTENSION = "images.yml"
    LATEST_IMAGES_FILENAME = "latest.#{IMAGES_EXTENSION}"
    LATEST_SNAP_ID_FILENAME = "latest.snapshot_id"
    SNAPSHOTS_DIR = "snapshots"
    TRANSFERS_DIR = "transfers"
    FAILED_SNAPSHOTS_SUBDIR = "failed"
    BUNDLE_CONF_DIR = "conf"

    def initialize(bundle_name)
      @bundle_name = bundle_name
      @file_name = "#{BUNDLE_CONF_DIR}/bundle.#{bundle_name}.yml"
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

    def save(args)
      if args[:patch_snapshot_id] && args[:patch_repositories]
        puts "\nSaving now ... (patch only)"
        patch_snapshot_id = args[:patch_snapshot_id]
        patch_repositories = args[:patch_repositories]
      else
        puts "\nSaving now ..."
      end
      
      if completed?
        target_dir = "#{SNAPSHOTS_DIR}/#{@name}"
      else
        target_dir = "#{SNAPSHOTS_DIR}/#{@name}/#{FAILED_SNAPSHOTS_SUBDIR}"
      end

      dt = DateTime.now
      today = dt.strftime("#{CALENDAR_PATTERN}")
      patch = find_patch(today, target_dir)
      new_patch = patch + 1
      SnapConfig::check_dir "#{target_dir}"
      save_to = "#{target_dir}/#{today}.#{new_patch}.#{IMAGES_EXTENSION}"
      save_snap_id_to = "#{target_dir}/#{LATEST_SNAP_ID_FILENAME}"

      if first_patch_today?(patch)
        puts "  first patch today 🎂 , party starts now! 🎉🎉🎉 , patch no #{Paint[new_patch, :green]}, for pattern 📅 #{Paint[today, :magenta]}"
      else
        puts "  `hallelujah`, 👏 found patch no #{Paint[patch, :cyan]}, 💪 upgrading to #{Paint[new_patch, :green]}, for pattern 📅 #{Paint[today, :magenta]}"
      end

      snapshot_id = "#{today}.#{new_patch}"
      yaml = make_yaml(snapshot_id, patch_snapshot_id, patch_repositories)
      File.write(save_to, yaml)
      puts "  💾 saved to file #{Paint[save_to, :cyan]}"
      File.write(save_snap_id_to, snapshot_id)
      puts "  🎉 snapshot id #{Paint[snapshot_id, :yellow]}, saved to file #{Paint[save_snap_id_to, :cyan]}"

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

    def parse
      @content = YAML.load_file(@file_name)
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

    def self.check_dir(dir_name)
      if File.directory? dir_name
        puts "  target 📁 #{Paint[dir_name, :green]} exists"
      else
        puts "  created target 📁 #{Paint[dir_name, :red]}"
        FileUtils.mkdir_p dir_name
      end
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

    def make_yaml(snapshot_id, patch_snapshot_id, patch_repositories)
      patch_only = true if (patch_snapshot_id && patch_repositories)
      
      if patch_only
        old_snapshot = load_patch_from_snapshot(patch_snapshot_id)
        repos_only = patch_repositories.split(",")
      end

      snapshot = SnapSnapshot.new(@bundle_name, snapshot_id, patch_snapshot_id, patch_repositories)
      each_bundles do |bundle|
        bundle.each_repos do |repos|
          digest = repos.detected_digest
          repos.add_transfer_tag(snapshot_id)

          patched = false
          
          if patch_only && old_snapshot.has_key?(repos.name)
            if repos_only.include?(repos.name)
              patched = true
            else
              # version from patched snapshot (old)! patch only repos from repos_only array!
              digest = old_snapshot[repos.name][:digest]
              repos.add_transfer_tag(old_snapshot[repos.name][:transfer_tag])
            end
          end
          uri = URI("#{repos.image_url}")
          snapshot.add_image(repos.name, repos.tag, repos.transfer_tag,
                             uri.host, uri.port, uri.scheme,
                             repos.project, repos.repository, digest, repos.detected?,
                             patched)
        end
      end
      snapshot.to_yaml
    end

    def load_patch_from_snapshot(patch_snapshot_id)
      result = {}
      if patch_snapshot_id
        snapshot_file = "#{Dir.getwd}/#{SNAPSHOTS_DIR}/#{@name}/#{patch_snapshot_id}.#{IMAGES_EXTENSION}"
        snapshot_data = YAML.load_file(snapshot_file)
        if snapshot_data.has_key? "images"
          snapshot_data["images"].each do |img|
            transfer_tag = img["transfer_tag"] || patch_snapshot_id
            result[img["name"]] = {digest: img["digest"], transfer_tag: transfer_tag}
          end
        end
      end
      result
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
    attr_reader :name, :tag, :keep_tag_as_is, :url, :project, :repository, :detected_digest, :transfer_tag

    def initialize(name, tag, keep_tag_as_is)
      @name = name
      @tag = tag
      @transfer_tag = nil
      @keep_tag_as_is = keep_tag_as_is
      @keep_tag_as_is |= false
      @detected = false
      @detected_digest = nil
    end

    def add_detected_digest(digest)
      @detected_digest = digest
    end

    def add_image_url(url, project, repository)
      @url = url
      @project = project
      @repository = repository
    end

    def add_transfer_tag(transfer_tag)
      @transfer_tag = transfer_tag
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

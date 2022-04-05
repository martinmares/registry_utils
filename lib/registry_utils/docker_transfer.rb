# encoding: UTF-8

module RegistryUtils
  require "docker"
  require "yaml"
  require "paint"
  require "awesome_print"
  require "json"
  require "benchmark"
  require_relative "snap_config"
  require_relative "snap_snapshot"

  class DockerTransfer
    attr_reader :docker, :docker_target, :docker_api
    attr_accessor :save_as

    def initialize(args)
      @bundle = args[:bundle]
      @snapshot_id = args[:snapshot_id]
      @target_bundle = args[:target_bundle]
      @target_project = args[:target_project]
      @target_url = args[:target_url]
      @pull_by = args[:pull_by] || "sha256"
      @target_user = args[:target_user]
      @target_pass = args[:target_pass]
      @docker_api = args[:docker_api]
      @add_tag ||= args[:add_tag]
      ENV["DOCKER_URL"] = @docker_api # https://github.com/swipely/docker-api
      @dry_run = args[:dry_run] || false
      @docker = DockerEndpoit.new(args[:url], args[:user], args[:pass])
      @target_docker = DockerEndpoit.new(args[:target_url], args[:target_user], args[:target_pass])
      @images = []
      @patch_only = args[:patch_only] || false
    end

    def self.open_with(args)
      c = DockerTransfer.new(args)
      c.load_snapshot()
      c.save_as = args[:save_as]
      yield(c)
    end

    def transfer_images
      # docker_auth(@docker) unless @dry_run
      # docker_auth(@target_docker) unless @dry_run

      snap = SnapSnapshot.new(@target_bundle, @snapshot_id)

      complete_took = Benchmark.measure do
        if patch_only?
          process_images = @images.select { |img| img.patched? }
          puts "Patch only `abracadabra` 🪄"
        else
          process_images = @images
        end

        process_images.each_with_index do |img, i|
          snap_img = nil
          took = Benchmark.measure do
            puts "[#{Paint[(i + 1).to_s.rjust(2, " "), :green]}] #{img.name}"

            pull_image = case @pull_by
              when "tag"
                img.docker_img_name_by_tag
              when "sha256"
                img.docker_img_name
              end

            docker_auth(@docker) unless @dry_run
            # puts " 🪄 `patched` image ... `wingardium leviosa`" if img.patched?
            puts "  👈 #{pull_image}"
            puts "  🙀 will be renamed to #{Paint[img.rename_to, :red]}" if img.rename_to

            unless @dry_run
              if @pull_by == "tag"
                local_img = Docker::Image.create("fromImage" => img.docker_img_name_by_tag)
              elsif @pull_by == "sha256"
                local_img = Docker::Image.create("fromImage" => img.docker_img_name)
              end
            end
            remote_img_name = DockerImage::generate_docker_img_name(@target_url, @target_project, img.name, img.rename_to)
            puts "  🎁 tag #{Paint[img.snapshot_id, :blue]}"

            docker_auth(@target_docker) unless @dry_run
            tag = img.snapshot_id

            local_img.tag("repo" => remote_img_name, "tag" => tag, force: true) unless @dry_run
            print "  👉 #{remote_img_name}:#{img.snapshot_id}"
            push_result = local_img.push(nil, repo_tag: "#{remote_img_name}:#{tag}") unless @dry_run
            target_sha_digest = parse_digest(push_result, remote_img_name) if push_result

            add_tags = []
            add_tags << tag
            if @add_tag
              @add_tag.each { |t| add_tags << t }
            end

            real_img_name = img.rename_to || img.name
            uri = URI("#{@target_url}/#{@target_project}/#{real_img_name}")
            snap.type = "transfer"
            snap_img = snap.add_image(real_img_name, nil, @save_as, tag, add_tags, uri.host, uri.port, uri.scheme, @target_project, img.name, target_sha_digest, nil, nil)
            print_result(push_result)

            if @add_tag
              @add_tag.each do |t|
                puts "  🎁 +tag #{Paint[t, :blue]}"
                local_img.tag("repo" => remote_img_name, "tag" => "#{t}", force: false) unless @dry_run
                print "  👉 #{remote_img_name}:#{t}"
                push_result = local_img.push(nil, repo_tag: "#{remote_img_name}:#{t}") unless @dry_run
                print_result(push_result)
              end
            end

            unless @dry_run
              begin
                local_img.remove()
              rescue => exception
                puts "  🌶️ exception: #{exception}"
              end
            end

            puts "\n"
          end

          if snap_img
            snap_img.transferred
            snap_img.took(took.real)
          end
        end
      end
      snap.transferred
      snap.took(complete_took.real)
      save_transfer_to_file(snap) unless @dry_run
    end

=begin

    images:
    - name: tsm-address-management
      tag: master
      host: registry.datalite.cz
      port: 443
      scheme: https
      project: tsm
      repository: tsm-address-management
      digest: sha256:e5612b8f850f3e5d305a788cca71752c7deb01075f9efb50306662b2cdb0c1b0
      detected: true
      patched: true

=end

    def load_snapshot
      puts "Loading snapshot #{Paint[@snapshot_id, :magenta]} from directory #{Paint[snapshot_file_name, :yellow]}"
      snap = YAML.load_file(snapshot_file_name)
      @snapshot_id = snap["snapshot_id"]
      puts "Loaded snapshot #{Paint[@snapshot_id, :green]}"
      @patch_snapshot_id = snap["patch_snapshot_id"]
      @patch_repositories = snap["patch_repositories"]

      # now in @args!
      # if @patch_snapshot_id && @patch_snapshot_id.size > 0
      #   @patch_only = true
      # end

      if snap.has_key? "images"
        snap["images"].each do |img|
          di = DockerImage.new(img["name"], img["rename_to"], snap["snapshot_id"], img["tag"], img["host"], img["port"], img["scheme"], img["project"], img["repository"], img["digest"], img["detected"], img["patched"])
          @images << di
        end
      end
    end

    private

    def patch_only?
      @patch_only
    end

    def print_result(result)
      if result
        puts " - ✅"
      else
        puts " - ❌"
      end
    end

    def docker_auth(endpoint)
      Docker.authenticate!("username" => endpoint.user, "password" => endpoint.pass, "serveraddress" => endpoint.url)
      puts "  🔑 authenticated to #{Paint[endpoint.url, :cyan]} with user #{endpoint.user}!"
    end

    def snapshot_file_name
      if @snapshot_id.downcase =~ /latest/
        "#{SnapConfig::SNAPSHOTS_DIR}/#{@bundle}/#{SnapConfig::LATEST_IMAGES_FILENAME}"
      else
        "#{SnapConfig::SNAPSHOTS_DIR}/#{@bundle}/#{@snapshot_id}.#{SnapConfig::IMAGES_EXTENSION}"
      end
    end

    def save_transfer_to_file(snap)
      target_dir = "#{SnapConfig::SNAPSHOTS_DIR}/#{@target_bundle}"
      SnapConfig::check_dir(target_dir)
      with_id = @save_as || @snapshot_id
      snap.add_from_snapshot_id(@save_as)
      save_to = "#{target_dir}/#{with_id}.#{SnapConfig::IMAGES_EXTENSION}"
      save_snap_id_to = "#{target_dir}/#{SnapConfig::LATEST_SNAP_ID_FILENAME}"

      File.write(save_to, snap.to_ruby_obj.to_yaml)
      puts "  💾 the content is saved to a file #{Paint[save_to, :cyan]}"
      File.write("#{target_dir}/#{SnapConfig::LATEST_IMAGES_FILENAME}", snap.to_ruby_obj.to_yaml)
      puts "  💾 the #{Paint['latest state', :green]} is saved to a file #{Paint[SnapConfig::LATEST_IMAGES_FILENAME, :green]}"
      File.write(save_snap_id_to, with_id)
      puts "  🎉 with snapshot id #{Paint[with_id, :yellow]}, saved to file #{Paint[save_snap_id_to, :cyan]}"
    end

    def parse_digest(push_result, find_by_repo)
      repo_digests = push_result.json["RepoDigests"]

      cnt = 0
      idx = 0
      repo_digests.each do |t|
        idx = cnt if t[find_by_repo]
        cnt += 1
      end
      digest = repo_digests[idx]

      # trick!
      result = (digest.reverse[0..digest.reverse.index(":") - 1]).reverse
      "sha256:#{result}"
    end
  end

  class DockerEndpoit
    attr_reader :url, :user, :pass

    def initialize(url, user, pass)
      @url = url
      @user = user
      @pass = pass
      puts "Created DockerEndpoint to: #{url}"
    end
  end

  class DockerImage
    attr_accessor :name, :rename_to, :snapshot_id, :tag, :host, :port, :scheme, :project, :repository, :digest, :detected, :patched

    def initialize(name, rename_to, snapshot_id, tag, host, port, scheme, project, repository, digest, detected, patched)
      @name = name
      @rename_to = rename_to
      @snapshot_id = snapshot_id
      @tag = tag
      @host = host
      @port = port
      @scheme = scheme
      @project = project
      @repository = repository
      @digest = digest
      @detected = detected
      @patched = patched
    end

    def docker_img_name
      "#{@host}:#{@port}/#{@project}/#{@repository}@#{@digest}"
    end

    def docker_img_name_by_tag
      "#{@host}:#{@port}/#{@project}/#{@repository}:#{@tag}"
    end

    def self.generate_docker_img_name(url, project, name, rename_to)
      new_name = rename_to || name
      uri = URI("#{url}/#{project}/#{new_name}")
      
      if uri.scheme == "https" && uri.port == 443
        "#{uri.host}#{uri.path}"
      elsif uri.scheme == "http" && uri.port == 80
        "#{uri.host}#{uri.path}"
      else
        "#{uri.host}:#{uri.port}#{uri.path}"
      end
    end

    def patched?
      @patched
    end
  end
end

=begin

  opt :url, "Harbor URL", type: :string, required: true, short: "-l"
  opt :user, "User name", type: :string, required: true, short: "-u"
  opt :pass, "Password", type: :string, required: true, short: "-e"
  opt :bundle, "Bundle name", type: :string, required: true, short: "-b"
  opt :snapshot, "Snapshot version (contains images with sha256 digests)", type: :string, required: true, short: "-s"
  opt :target_project, "Project name (target)", type: :string, required: true, short: "-p"
  opt :target_url, "Harbor URL (target)", type: :string, required: true, short: "-t"
  opt :target_user, "User name (target)", type: :string, required: true, short: "-n"
  opt :target_pass, "Password (target)", type: :string, required: true, short: "-w"

=end

module RegistryUtils

  require "docker"
  require "yaml"
  require "paint"
  require "awesome_print"
  require "json"
  require_relative "snap_config"
  require_relative "snap_snapshot"

  class DockerTransfer
    attr_reader :docker, :docker_target, :docker_api

    def initialize(args)
      @bundle = args[:bundle]
      @snapshot_id = args[:snapshot_id]
      @target_bundle = args[:target_bundle]
      @target_project = args[:target_project]
      @target_url = args[:target_url]
      @target_user = args[:target_user]
      @target_pass = args[:target_pass]
      @docker_api = args[:docker_api]
      @add_tag = args[:add_tag] || nil
      ENV["DOCKER_URL"] = @docker_api # https://github.com/swipely/docker-api
      @docker_fake = args[:docker_fake] || false
      @docker = DockerEndpoit.new(args[:url], args[:user], args[:pass])
      @target_docker = DockerEndpoit.new(args[:target_url], args[:target_user], args[:target_pass])
      @images = []
      @patch_only = false
    end

    def self.open_with(args)
      c = DockerTransfer.new(args)
      c.load_snapshot()
      yield(c)
    end

    def transfer_images
      docker_auth(@docker) unless @docker_fake
      docker_auth(@target_docker) unless @docker_fake

      snap = SnapSnapshot.new(@target_bundle, @snapshot_id)
      
      if patch_only?
        process_images = @images.select { |img| img.patched? }
        puts "Patch only `abracadabra` 🪄"
      else
        process_images = @images
      end

      process_images.each_with_index do |img, i|
        puts "[#{Paint[(i+1).to_s.rjust(2, ' '), :green]}] #{img.name}"
        puts "  👈 #{img.docker_img_name}"
        unless @docker_fake
          local_img = Docker::Image.create('fromImage' => img.docker_img_name)
        end
        remote_img_name = DockerImage::generate_docker_img_name(@target_url, @target_project, img.name)
        puts "  🎁 #{img.snapshot_id}"

        tag = img.snapshot_id

        local_img.tag('repo' => remote_img_name, 'tag' => tag, force: true) unless @docker_fake
        puts "  👉 #{remote_img_name}:#{img.snapshot_id}"
        push_result = local_img.push(nil, repo_tag: "#{remote_img_name}:#{tag}") unless @docker_fake
        
        # target_sha_digest = push_result.json["Id"] if push_result
        target_sha_digest = parse_digest(push_result, img.docker_img_name) if push_result

        # to_docker_image = docker_image.push(nil, repo_tag: new_image_name)
        # to_image_id = to_docker_image.json['Id']
        # add_image(name, tag, transfer_tag, host, port, scheme, project, repository, digest, detected, patched)

        transfer_tag = tag
        transfer_tag = @add_tag if @add_tag

        uri = URI("#{@target_url}/#{@target_project}/#{img.name}")
        snap.add_image(img.name, tag, transfer_tag, uri.host, uri.port, uri.scheme, @target_project, img.name, target_sha_digest, nil, nil)
        print_result(push_result)
        
        if @add_tag
          puts "  🎁 add tag #{@add_tag}"
          local_img.tag('repo' => remote_img_name, 'tag' => "#{@add_tag}" , force: true) unless @docker_fake
          puts "  👉 #{remote_img_name}:#{@add_tag}"
          push_result = local_img.push(nil, repo_tag: "#{remote_img_name}:#{@add_tag}") unless @docker_fake
          print_result(push_result)
        end

        local_img.remove(:force => true) unless @docker_fake
        puts "\n"
      end
      save_transfer_to_file(snap) unless @docker_fake
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
      @patch_snapshot_id = snap["patch_snapshot_id"]
      @patch_repositories = snap["patch_repositories"]
      if @patch_snapshot_id && @patch_snapshot_id.size > 0
        @patch_only = true
      end
      if snap.has_key? "images"
        snap["images"].each do |img|
          di = DockerImage.new(img["name"], snap["snapshot_id"], img["tag"], img["host"], img["port"], img["scheme"], img["project"], img["repository"], img["digest"], img["detected"], img["patched"])
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
        puts "     ✅  Everything is OK, `meow` 😺"
      else
        puts "     ❌  I'm crying, `meow` 😿"
      end
    end

    def docker_auth(endpoint)
      Docker.authenticate!('username' => endpoint.user, \
                           'password' => endpoint.pass, \
                           'serveraddress' => endpoint.url)
      puts "🔑 authenticated to #{Paint[endpoint.url, :cyan]} with user #{endpoint.user}!"
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
      save_to = "#{target_dir}/#{@snapshot_id}.#{SnapConfig::IMAGES_EXTENSION}"
      File.write(save_to, snap.to_yaml)
      puts "  💾 saved to file #{Paint[save_to, :cyan]}"
    end

    def parse_digest(push_result, tag)
      repo_digests = push_result.json['RepoDigests']
    
      cnt = 0
      idx = 0
      repo_digests.each do |t|
        idx = cnt if t[tag]
        cnt += 1
      end
      digest = repo_digests[idx]
    
      # trick!
      result = (digest.reverse[0..digest.reverse.index(':') - 1]).reverse
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
    attr_accessor :name, :snapshot_id, :tag, :host, :port, :scheme, :project, :repository, :digest, :detected, :patched
    def initialize(name, snapshot_id, tag, host, port , scheme, project, repository, digest, detected, patched)
      @name = name
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

    def self.generate_docker_img_name(url, project, name)
      uri = URI("#{url}/#{project}/#{name}")
      "#{uri.host}:#{uri.port}#{uri.path}"
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

module HarborUtils

  require "docker"
  require "yaml"
  require "paint"
  require "awesome_print"
  require "json"
  require_relative "snap_config"

  class DockerTransfer
    attr_reader :docker, :docker_target, :docker_api

    def initialize(args)
      @bundle = args[:bundle]
      @snapshot = args[:snapshot]
      @target_project = args[:target_project]
      @target_url = args[:target_url]
      @target_user = args[:target_user]
      @target_pass = args[:target_pass]
      @docker_api = args[:docker_api]
      @latest_tag = args[:latest_tag] || false
      ENV["DOCKER_URL"] = @docker_api # https://github.com/swipely/docker-api
      @docker = DockerEndpoit.new(args[:url], args[:user], args[:pass])
      @target_docker = DockerEndpoit.new(args[:target_url], args[:target_user], args[:target_pass])
      @images = []
    end

    def self.open_with(args)
      c = DockerTransfer.new(args)
      c.load_snapshot()
      yield(c)
    end

    def transfer_images
      @images.each_with_index do |img, i|
        puts "[#{Paint[(i+1).to_s.rjust(2, ' '), :green]}] #{img.name}"
        docker_auth(@docker)
        puts "  👈 #{img.docker_img_name}"
        local_img = Docker::Image.create('fromImage' => img.docker_img_name)
        remote_img_name = DockerImage::generate_docker_img_name(@target_url, @target_project, img.name)
        puts "  🎁 #{img.snapshot_id}"
        local_img.tag('repo' => remote_img_name, 'tag' => img.snapshot_id , force: true)
        docker_auth(@target_docker)
        puts "  👉 #{remote_img_name}:#{img.snapshot_id}"
        push_result = local_img.push(nil, repo_tag: "#{remote_img_name}:#{img.snapshot_id}")
        print_result(push_result)
        
        if @latest_tag
          puts "  🎁 latest"
          local_img.tag('repo' => remote_img_name, 'tag' => "latest" , force: true)
          docker_auth(@target_docker)
          puts "  👉 #{remote_img_name}:latest"
          push_result = local_img.push(nil, repo_tag: "#{remote_img_name}:latest")
          print_result(push_result)
        end

        local_img.remove(:force => true)

        puts "\n"
      end
    end
    # docker pull registry.datalite.cz/tsm-cetin-release/snapshot/tsm-address-management@sha256:19b6b4c3248635171a2a3ef772416a82295a7f4858495b10d1dc67148157de73
=begin

    images:
    - name: tsm-address-management
      tag: master
      url: https://registry.datalite.cz
      project: tsm
      repository: tsm-address-management
      digest: sha256:f32840e0ecb110824be4ef24859c77e308929c109a740be60211fdfad2e16bc2
      image_url: https://registry.datalite.cz/tsm/tsm-address-management
      detected: true

=end

    def load_snapshot
      puts "Loading snapshot #{Paint[@snapshot, :magenta]} from directory #{Paint[snapshot_file_name, :yellow]}"
      snap = YAML.load_file(snapshot_file_name)
      if snap.has_key? "images"
        snap["images"].each do |img|
          di = DockerImage.new(img["name"], snap["snapshot_id"], img["tag"], img["host"], img["port"], img["scheme"], img["project"], img["repository"], img["digest"], img["detected"])
          @images << di
        end
      end
    end

    private

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
    end

    def snapshot_file_name
      if @snapshot.downcase =~ /latest/
        "#{SnapConfig::SNAPSHOTS_DIR}/#{@bundle}/#{SnapConfig::LATEST_IMAGES_FILENAME}"
      else
        "#{SnapConfig::SNAPSHOTS_DIR}/#{@bundle}/#{@snapshot}.#{SnapConfig::IMAGES_EXTENSION}"
      end
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
    attr_accessor :name, :snapshot_id, :tag, :host, :port, :scheme, :project, :repository, :digest, :detected
    def initialize(name, snapshot_id, tag, host, port , scheme, project, repository, digest, detected)
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
    end

    def docker_img_name
      "#{@host}:#{@port}/#{@project}/#{@repository}@#{@digest}"
    end

    def self.generate_docker_img_name(url, project, name)
      uri = URI("#{url}/#{project}/#{name}")
      "#{uri.host}:#{uri.port}#{uri.path}"
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

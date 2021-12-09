module HarborUtils

  require "yaml"
  require "awesome_print"

  class SnapSnapshot

    def initialize(bundle, snapshot_id, patch_snapshot_id, patch_repositories)
      @timestamp = DateTime.now.to_s
      @utc = DateTime.now.new_offset(0).to_s
      @bundle = bundle
      @snapshot_id = snapshot_id
      @patch_snapshot_id = patch_snapshot_id
      @patch_repositories = patch_repositories
      @images = []
    end

    def add_image(name, tag, host, port, scheme, project, repository, digest, detected, patched)
      @images << SnapImage.new(name, tag, host, port, scheme, project, repository, digest, detected, patched)
    end

    def to_yaml
      reqult = {}
      images = []
      @images.each do |image|
        images << image.to_yaml
      end
      result = {
        "timestamp" => @timestamp,
        "utc" => @utc,
        "bundle" => @bundle,
        "snapshot_id" => @snapshot_id
      }
      result["patch_snapshot_id"] = @patch_snapshot_id if @patch_snapshot_id
      result["patch_repositories"] = @patch_repositories if @patch_repositories
      result["images"] = images if images
      result.to_yaml
    end

  end

  class SnapImage
    def initialize(name, tag, host, port, scheme, project, repository, digest, detected, patched)
      @name = name
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

    def to_yaml
      {
        "name" => @name,
        "tag" => @tag,
        "host" => @host,
        "port" => @port,
        "scheme" => @scheme,
        "project" => @project,
        "repository" => @repository,
        "digest" => @digest,
        "detected" => @detected,
        "patched" => @patched
      }
    end
  end

end

=begin

  ---
  timestamp: '2021-12-07T21:11:33+01:00'
  utc: '2021-12-07T20:11:33+00:00'
  snapshot_id: 2021.12.07.0
  images:
  - name: tsm-address-management
    tag: master
    host: registry.datalite.cz
    port: 443
    scheme: https
    project: tsm
    repository: tsm-address-management
    digest: sha256:355c45aee9e52d6b4ba752f79f3e426a39fad5a7af3559c5c5b1df62f8c2a451
    detected: true

=end

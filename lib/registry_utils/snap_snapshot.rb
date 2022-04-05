module RegistryUtils

  require "yaml"
  require "awesome_print"

  class SnapSnapshot

    attr_writer :type

    def initialize(bundle, snapshot_id, patch_snapshot_id=nil, patch_repositories=nil)
      @timestamp = DateTime.now.to_s
      @utc = DateTime.now.new_offset(0).to_s
      @type = "snapshot"
      @bundle = bundle
      @snapshot_id = snapshot_id
      @patch_snapshot_id = patch_snapshot_id
      @patch_repositories = patch_repositories
      @images = []
    end

    def add_image(name, rename_to, save_as, tag, add_tags, host, port, scheme, project, repository, digest, detected, patched)
      new_img = SnapImage.new(name, rename_to, save_as, tag, add_tags, host, port, scheme, project, repository, digest, detected, patched)
        @images << new_img
      new_img
    end

    def add_from_snapshot_id(new_snap_id)
      if new_snap_id
        @from_snapshot_id = @snapshot_id
        @snapshot_id = new_snap_id
      end
    end

    def transferred
      @transferred = {
        "timestamp" => DateTime.now.to_s,
        "utc" => DateTime.now.new_offset(0).to_s
      }
    end

    def took(sec)
      @took = sec
    end

    def to_ruby_obj
      result = {
        "timestamp" => @timestamp,
        "utc" => @utc,
        "type" => @type,
        "bundle" => @bundle,
        "snapshot_id" => @snapshot_id
      }
      result["took"] = @took if @took
      result["transferred"] = @transferred if @transferred

      result["from_snapshot_id"] = @from_snapshot_id if @from_snapshot_id
      result["patch_snapshot_id"] = @patch_snapshot_id if @patch_snapshot_id
      result["patch_repositories"] = @patch_repositories if @patch_repositories

      images = []
      @images.each do |image|
        images << image.to_ruby_obj
      end
      result["images"] = images if images

      result
    end

  end

  class SnapImage
    def initialize(name, rename_to, save_as, tag, add_tags, host, port, scheme, project, repository, digest, detected, patched)
      @name = name
      @rename_to = rename_to
      @save_as = save_as
      @tag = tag
      @add_tags = add_tags
      @host = host
      @port = port
      @scheme = scheme
      @project = project
      @repository = repository
      @digest = digest
      @detected = detected
      @patched = patched
    end

    def transferred
      @transferred = {
        "timestamp" => DateTime.now.to_s,
        "utc" => DateTime.now.new_offset(0).to_s
      }
    end

    def took(sec)
      @took = sec
    end

    def to_ruby_obj
      result = Hash.new
      result["name"] = @name
      result["rename_to"] = @rename_to if @rename_to
      result["took"] = @took if @took
      result["transferred"] = @transferred if @transferred

      if @save_as
        result["tag"] = @save_as
        # result["from_tag"] = @tag
      else
        result["tag"] = @tag
      end

      if @add_tags
        add_tags = @add_tags.uniq.reject { |e| e == result["tag"] }
        result["add_tags"] = add_tags.dup if add_tags.size > 0
      end
      result["host"] = @host
      result["port"] = @port
      result["scheme"] = @scheme
      result["project"] = @project
      result["repository"] = @rename_to || @repository
      result["digest"] = @digest
      result["detected"] = @detected if @detected
      result["patched"] = @patched if @patched

      result
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

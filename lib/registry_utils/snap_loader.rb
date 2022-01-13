module RegistryUtils

  require_relative "snap_config"

  class SnapLoader
    attr_reader :config

    def initialize(bundle_name)
      @config = SnapConfig.new(bundle_name)
    end

    def snap()
      puts "Create snapshot..."
    end

    def self.with_config(bundle_name)
      s = self.new(bundle_name)
      yield(s.config)
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
  - name: tsm-cetin-deco
    project: tsm
    repositories:
      - name: tsm-cetin-deco-prioritizer
        tag: test
      - name: tsm-cetin-deco-distributor
        tag: test
      - name: tsm-cetin-deco-sluzby
        tag: test
  - name: tsm-infra
    project: tsm
    repositories:
      - name: tsm-elasticsearch-proxy
        tag: 1.0.1
        keep_tag_as_is: true
      - name: tsm-reproxy
        tag: 1.0.2
        keep_tag_as_is: true
      - name: tsm-log-server
        tag: 1.0.3
        keep_tag_as_is: true

=end

# frozen_string_literal: true

require 'k8s_backend'
require 'pry'

module Inspec::Resources
  class K8sObject < ::K8sResourceBase
    name 'k8sobject'
    desc 'Verifies settings for a single resource'

    example "
      describe k8sobject(api: 'v1', type: 'pod', namespace: 'default', name: 'my-pod') do
        it { should exist }
        its('name') { should eq 'my-pod' }
        ...
      end
    "
    attr_reader :k8sobject

    def initialize(opts = {})
      # Call the parent class constructor
      super(opts)

      @objapi = opts[:api] if opts[:api] ||= 'v1'
      @objtype = opts[:type] if opts[:type] ||= nil
      @objname = opts[:name] if opts[:name] ||= nil
      @objnamespace = opts[:namespace] if opts[:namespace] ||= nil

      @display_name = if !@objnamespace.nil?
                        "#{@objnamespace}/#{@objname}"
                      else
                        @objname.to_s
                      end
      catch_k8s_errors do
        @k8sobject = if !@objnamespace.nil?
                       @k8s.client.api(@objapi).resource(@objtype, namespace: @objnamespace).get(@objname)
                     else
                       @k8s.client.api(@objapi).resource(@objtype).get(@objname)
                     end
      end
    end

    def item
      @k8sobject
    end

    def container_names
      if @k8sobject.respond_to?(:spec) && @k8sobject.spec.respond_to?(:containers) && @k8sobject.spec.containers.respond_to?(:name)
        @k8sobject.spec.containers.map do |c|
          c.name
        end
      end
    end

    def container_images
      @k8sobject.spec.containers.map { |c| c.image } unless @k8sobject.spec.containers.nil?
    end

    def has_latest_container_tag?
      if @k8sobject.respond_to?(:spec) && @k8sobject.spec.respond_to?(:containers)
        @k8sobject.spec.containers.map { |c| c.image }.each do |i|
          return true if i =~ /^.*:latest$/
        end
      end
      false
    end

    def has_label?(objlabel = nil)
      if @k8sobject.respond_to?(:metadata) && @k8sobject.metadata.respond_to?(:labels) && @k8sobject.metadata.labels.respond_to?(objlabel) && !@k8sobject.metadata.labels[objlabel].nil?
        return true
      end

      false
    end

    def exists?
      !@k8sobject.nil?
    end

    def to_s
      @display_name.to_s
    end

    def name
      @k8sobject.metadata.name unless @k8sobject.metadata.name.nil?
    end

    def include?(key)
      @k8sobject.key?(key)
    end

    def running?
      @k8sobject.status.phase == 'Running' unless @k8sobject.status.phase.nil?
    end
  end
end

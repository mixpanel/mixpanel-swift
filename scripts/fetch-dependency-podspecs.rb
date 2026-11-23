#!/usr/bin/env ruby
# frozen_string_literal: true

# CocoaPods trunk is read-only from December 2, 2026, so new versions of Mixpanel pods
# are only published as git tags. `pod lib lint` resolves dependencies from trunk, so it
# fails once this podspec needs a Mixpanel dependency version that trunk doesn't have.
#
# For each Mixpanel dependency (including dependencies of dependencies) that trunk
# can't satisfy, this script downloads the dependency's podspec from the newest git tag
# that matches the requirement into OUT_DIR. Pass those podspecs to the lint:
#
#   ruby scripts/fetch-dependency-podspecs.rb Mixpanel-swift.podspec deps
#   pod lib lint Mixpanel-swift.podspec --allow-warnings --external-podspecs='deps/*.podspec'
#
# When trunk satisfies every dependency, OUT_DIR stays empty and lint behaves as before.
# Set MIXPANEL_PODS_FROM_GIT=1 to always use git tags (useful for testing).
#
# Needs only Ruby's standard library plus `pod`, `git` and `curl` on the PATH.
#
# Usage: ruby scripts/fetch-dependency-podspecs.rb PODSPEC OUT_DIR

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'rubygems'

MIXPANEL_PODS = {
  'MixpanelSwiftCommon' => 'mixpanel/mixpanel-swift-common',
  'Mixpanel-swift' => 'mixpanel/mixpanel-swift',
  'MixpanelSessionReplay' => 'mixpanel/mixpanel-ios-session-replay-package'
}.freeze

def run(*cmd)
  out, status = Open3.capture2(*cmd)
  status.success? ? out : nil
end

# Podspec as JSON, via the installed CocoaPods.
def load_spec(path)
  json = run('pod', 'ipc', 'spec', path) or abort("Could not read #{path} with `pod ipc spec`")
  JSON.parse(json)
end

# All dependencies in the spec, its platform sections and its subspecs, as { name => [requirements] }.
def dependencies(node, found = Hash.new { |h, k| h[k] = [] })
  case node
  when Hash
    node.each do |key, value|
      if key == 'dependencies' && value.is_a?(Hash)
        value.each { |name, reqs| found[name.split('/').first].concat(Array(reqs)) }
      else
        dependencies(value, found)
      end
    end
  when Array
    node.each { |child| dependencies(child, found) }
  end
  found
end

# Versions published on trunk, from the CocoaPods CDN shard for this pod.
def trunk_versions(name)
  shard = Digest::MD5.hexdigest(name)[0, 3].chars.join('_')
  index = run('curl', '-fsSL', '--retry', '3', "https://cdn.cocoapods.org/all_pods_versions_#{shard}.txt") or
    abort("Could not read the CocoaPods CDN index for #{name}")
  line = index.lines.find { |l| l.split('/').first == name }
  line ? line.strip.split('/').drop(1).map { |v| Gem::Version.new(v) } : []
end

# Release tags in the dependency's repository, as { version => tag }.
def git_tags(repo)
  out = run('git', 'ls-remote', '--tags', '--refs', "https://github.com/#{repo}.git") or
    abort("Could not list tags for #{repo}")
  out.lines.each_with_object({}) do |line, tags|
    tag = line.split("\t").last.strip.delete_prefix('refs/tags/')
    version = tag.delete_prefix('v')
    tags[Gem::Version.new(version)] = tag if version.match?(/\A\d+\.\d+\.\d+\z/)
  end
end

def fetch(spec, out_dir, seen)
  dependencies(spec).each do |name, reqs|
    repo = MIXPANEL_PODS[name]
    # Skip non-Mixpanel pods, pods already handled, and the pod's own subspecs.
    next if repo.nil? || seen.include?(name) || name == spec['name']

    seen << name
    requirement = Gem::Requirement.new(*reqs)
    unless ENV['MIXPANEL_PODS_FROM_GIT'] == '1'
      next if trunk_versions(name).any? { |v| requirement.satisfied_by?(v) }
    end

    version, tag = git_tags(repo).select { |v, _| requirement.satisfied_by?(v) }.max_by(&:first)
    abort("No #{name} release on trunk or in #{repo} matches #{requirement}") if tag.nil?

    body = run('curl', '-fsSL', '--retry', '3', "https://raw.githubusercontent.com/#{repo}/#{tag}/#{name}.podspec") or
      abort("Could not download #{name}.podspec at tag #{tag}")
    path = File.join(out_dir, "#{name}.podspec")
    File.write(path, body)
    warn "#{name} #{requirement}: not on trunk, using #{version} from #{repo} tag #{tag}"

    fetch(load_spec(path), out_dir, seen)
  end
end

abort('Usage: ruby scripts/fetch-dependency-podspecs.rb PODSPEC OUT_DIR') unless ARGV.size == 2
podspec, out_dir = ARGV
FileUtils.mkdir_p(out_dir)
fetch(load_spec(podspec), out_dir, [])

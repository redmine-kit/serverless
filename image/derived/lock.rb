# frozen_string_literal: true

# Keeps the gems of the base image at their versions in a derived image
# (image/derived/Dockerfile). Run from Redmine's directory:
#   ruby lock.rb base <file>               # the base image's gems, before anything is added
#   ruby lock.rb pins <file>               # Gemfile lines that hold them, after the plugins are added
#   ruby lock.rb gemfile <file> <Gemfile>  # a Gemfile of the added gems alone, with the same pins
#   ruby lock.rb checksums <lockfile>      # the added gems' checksums, from that Gemfile's lock
#   ruby lock.rb check <file>              # after bundle lock: fails if a gem of the base image has moved
# The base image's gems are those Bundler loads (without the development and
# test groups). bundle lock alone keeps them only as a preference, and moves
# one when an added gem needs another version, so the gems from RubyGems that
# no Gemfile names are pinned to their versions: Bundler then picks versions
# of the added gems that fit. A gem that a Gemfile names keeps that
# requirement, and the check catches it if it moves.
#
# Without a token for GitHub Packages, Bundler cannot read the base image's
# GitHub Packages source. The added gems are then installed from a Gemfile of
# their own, without that source, and Redmine's lock is made from the
# installed gems (bundle lock --local), which cannot fetch checksums: they
# come from that Gemfile's lock.
require 'bundler'

def base_gems(file)
  File.readlines(file, chomp: true).to_h(&:split)
end

def from_rubygems
  locked = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock')).specs
  locked.select do |spec|
    spec.source.is_a?(Bundler::Source::Rubygems) && spec.source.remotes.any? { |uri| uri.host == 'rubygems.org' }
  end.map(&:name)
end

def pins(file, named)
  pinned = from_rubygems - named
  base_gems(file).filter_map do |name, version|
    "gem '#{name}', '= #{version}', require: false" if pinned.include?(name)
  end
end

mode, file, gemfile = ARGV
case mode
when 'base'
  # Bundler itself is not a locked gem (BUNDLED WITH).
  specs = Bundler.definition.specs.reject { |spec| spec.name == 'bundler' }
  File.write(file, specs.map { |spec| "#{spec.name} #{spec.version}\n" }.uniq.join)
when 'pins'
  puts "# The base image's gems at their versions (image/derived/lock.rb).",
       pins(file, Bundler.definition.dependencies.map(&:name))
when 'gemfile'
  plugin_gemfiles = Dir.glob(File.expand_path('plugins/*/{Gemfile,PluginGemfile}'))
  File.write(gemfile, <<~RUBY)
    source 'https://rubygems.org'
    eval_gemfile '/tmp/derived/Gemfile.plugins'
    #{plugin_gemfiles.map { |path| "eval_gemfile #{path.dump}" }.join("\n")}
  RUBY
  dsl = Bundler::Dsl.new
  dsl.eval_gemfile(gemfile)
  File.write(gemfile, "#{pins(file, dsl.dependencies.map(&:name)).join("\n")}\n", mode: 'a')
when 'checksums'
  # Lines of the CHECKSUMS section: "  name (version) sha256=...".
  known = File.readlines(file).grep(/ sha256=/).to_h { |line| [line.split(' sha256=').first, line] }
  section = false
  lines = File.readlines('Gemfile.lock').map do |line|
    section = line.start_with?('CHECKSUMS') || (section && line.start_with?('  '))
    section && !line.include?(' sha256=') ? known.fetch(line.chomp, line) : line
  end
  File.write('Gemfile.lock', lines.join)
when 'check'
  locked = Bundler::LockfileParser.new(Bundler.read_file('Gemfile.lock')).specs
  moved = base_gems(file).filter_map do |name, version|
    now = locked.select { |spec| spec.name == name }.map { |spec| spec.version.to_s }.uniq
    "#{name} #{version} -> #{now.empty? ? 'removed' : now.join(', ')}" unless now == [version]
  end
  unless moved.empty?
    warn 'The added plugins need other versions of gems in the base image, which a derived image keeps:'
    moved.each { |line| warn "  #{line}" }
    warn 'Choose plugin versions that work with the base image\'s gems, or a base image that has those versions.'
    exit 1
  end
else
  abort 'usage: ruby lock.rb base|pins|gemfile|checksums|check <file> [Gemfile]'
end

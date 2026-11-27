#!/usr/bin/env ruby
# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require "json"
require "pathname"
require "rexml/document"
require "uri"
require "yaml"

SITE_DIR = "_site"
REQUIRED_FILES = %w[
  index.html
  print.html
  404.html
  llms.txt
  llms-full.txt
  resume.json
  .well-known/ard.json
  assets/css/main.css
  assets/js/main.js
  assets/font/IBMVGA8.woff2
  assets/Adam_Kauffman_Resume.pdf
  favicon.ico
  sitemap.xml
  robots.txt
].freeze
FORBIDDEN_TOP_LEVEL_ENTRIES = %w[
  scripts
  CNAME
  README.md
  Gemfile
  Gemfile.lock
  docker-compose.yml
  start
  .ruby-version
].freeze

errors = []

def local_target_exists?(path)
  clean = path.sub(%r{\A/+}, "")
  return File.exist?(File.join(SITE_DIR, "index.html")) if clean.empty?

  candidates = [
    File.join(SITE_DIR, clean),
    File.join(SITE_DIR, clean, "index.html"),
    File.join(SITE_DIR, "#{clean}.html")
  ]
  candidates.any? { |c| File.file?(c) }
end

# 1. Load site URL from _config.yml
config = YAML.safe_load_file("_config.yml") || {}
site_url = config["url"].to_s.chomp("/")
unless site_url.start_with?("https://")
  errors << "_config.yml: expected https:// url, got #{site_url.inspect}"
end

# 2. Required output files exist and are non-empty
REQUIRED_FILES.each do |rel_path|
  full_path = File.join(SITE_DIR, rel_path)
  if !File.file?(full_path)
    errors << "missing required output file: #{full_path}"
  elsif File.size(full_path).zero?
    errors << "empty required output file: #{full_path}"
  end
end

# 3. Forbidden / leaked artifacts (sourcemaps and excluded repo files)
Dir.glob(File.join(SITE_DIR, "**", "*.map")).each do |map_file|
  errors << "unexpected sourcemap in build output: #{map_file}"
end

FORBIDDEN_TOP_LEVEL_ENTRIES.each do |entry|
  leaked = File.join(SITE_DIR, entry)
  errors << "excluded file leaked into build output: #{leaked}" if File.exist?(leaked)
end

# 4. Validate HTML files (links, images, security attrs, Liquid leaks, icons)
html_files = Dir.glob(File.join(SITE_DIR, "**", "*.html")).sort
if html_files.empty?
  errors << "no HTML files found in #{SITE_DIR}/; run jekyll build before validating"
end

html_files.each do |file|
  html = File.read(file)

  if html.include?("http://localhost")
    errors << "#{file}: contains http://localhost URL"
  end

  html_without_styles = html.gsub(/<style\b[^>]*>.*?<\/style>/im, "")
  if html_without_styles.match?(/\{\{|\}\}|\{%|%\}/) || html.match?(/\{\{|\{%/)
    errors << "#{file}: contains unrendered Liquid template syntax"
  end

  html.scan(/<style\b[^>]*>(.*?)<\/style>/im) do |style_match|
    style_match[0].scan(/url\(\s*(['"]?)([^)'"]+)\1\s*\)/i) do |url_match|
      ref = url_match[1].strip
      next if ref.empty? || ref.start_with?("data:", "http://", "https://", "//", "#")

      clean_ref = ref.split(/[?#]/).first
      unless clean_ref.start_with?("/") && local_target_exists?(clean_ref)
        errors << "#{file}: invalid or missing inline CSS url() target: #{ref}"
      end
    end
  end

  if html.match?(/Liquid (?:error|Warning)/i)
    errors << "#{file}: contains Liquid error/warning output"
  end

  if html.match?(/<span\b[^>]*class="[^"]*\bsection-icon\b[^"]*"[^>]*>\s*<\/span>/m)
    errors << "#{file}: empty section-icon span (possible missing icon name)"
  end

  html.scan(/\b(?:href|src)="([^"]*)"/) do |match|
    url = match[0]
    if url.empty?
      errors << "#{file}: empty href/src attribute"
    elsif url.start_with?("//http://", "//https://")
      errors << "#{file}: malformed protocol-relative URL: #{url}"
    elsif url.start_with?("http://")
      errors << "#{file}: insecure http:// link: #{url}"
    elsif url.start_with?("/") && !url.start_with?("//")
      path = url.split(/[?#]/).first
      unless local_target_exists?(path)
        errors << "#{file}: missing local target: #{url}"
      end
    end
  end

  html.scan(/<a\b[^>]*>/im) do |tag|
    next unless tag.match?(/\btarget="_blank"/i)

    rel_match = tag.match(/\brel="([^"]*)"/i)
    rel_tokens = rel_match ? rel_match[1].downcase.split : []
    unless rel_tokens.include?("noopener") && rel_tokens.include?("noreferrer")
      errors << "#{file}: target=\"_blank\" link missing rel=\"noopener noreferrer\": #{tag}"
    end
  end

  html.scan(/<img\b[^>]*>/im) do |tag|
    alt_match = tag.match(/\balt="([^"]*)"/i)
    if alt_match.nil? || alt_match[1].strip.empty?
      errors << "#{file}: <img> missing non-empty alt attribute: #{tag}"
    end
  end
end

# 5. Validate CSS local url(...) references
site_root = Pathname.new(File.expand_path(SITE_DIR))
css_files = Dir.glob(File.join(SITE_DIR, "**", "*.css")).sort
css_files.each do |file|
  css = File.read(file)
  css.scan(/url\(\s*(['"]?)([^)'"]+)\1\s*\)/i) do |match|
    ref = match[1].strip
    next if ref.empty? || ref.start_with?("data:", "http://", "https://", "//", "#")

    clean_ref = ref.split(/[?#]/).first
    target = if clean_ref.start_with?("/")
               site_root.join(clean_ref.sub(%r{\A/+}, ""))
             else
               Pathname.new(File.expand_path(File.dirname(file))).join(clean_ref).cleanpath
             end

    within_site = target.to_s == site_root.to_s || target.to_s.start_with?("#{site_root}/")
    unless within_site && target.file?
      errors << "#{file}: missing CSS url() target: #{ref}"
    end
  end
end

# 6. Validate sitemap.xml and robots.txt
sitemap_path = File.join(SITE_DIR, "sitemap.xml")
if File.file?(sitemap_path) && site_url.start_with?("https://")
  begin
    doc = REXML::Document.new(File.read(sitemap_path))
    locs = doc.elements.to_a("//url/loc").map { |el| el.text.to_s.strip }
    if locs.empty?
      errors << "#{sitemap_path}: contains no <loc> entries"
    else
      locs.each do |loc|
        unless loc == site_url || loc.start_with?("#{site_url}/")
          errors << "#{sitemap_path}: unexpected <loc> origin (expected #{site_url}): #{loc}"
          next
        end
        path = URI.parse(loc).path
        if path == "/404.html"
          errors << "#{sitemap_path}: should not include /404.html"
        end
        unless local_target_exists?(path)
          errors << "#{sitemap_path}: <loc> target missing in #{SITE_DIR}/: #{loc}"
        end
      end
    end
  rescue REXML::ParseException => e
    errors << "#{sitemap_path}: invalid XML (#{e.message.lines.first.strip})"
  end
end

robots_path = File.join(SITE_DIR, "robots.txt")
if File.file?(robots_path) && site_url.start_with?("https://")
  robots = File.read(robots_path)
  expected_sitemap = "Sitemap: #{site_url}/sitemap.xml"
  errors << "#{robots_path}: missing '#{expected_sitemap}'" unless robots.include?(expected_sitemap)
  errors << "#{robots_path}: contains localhost reference" if robots.include?("localhost")
end

# 7. Validate icon.html references across includes/layouts
icon_defs_path = "_includes/icon.html"
if File.file?(icon_defs_path)
  defined_icons = File.read(icon_defs_path).scan(/when\s+['"]([^'"]+)['"]/).flatten.uniq
  Dir.glob("{_includes,_layouts}/**/*.html").each do |tpl|
    next if tpl == icon_defs_path

    File.read(tpl).scan(/\{%-?\s*include\s+icon\.html\b[^%]*\bname=['"]([^'"]+)['"]/) do |match|
      name = match[0]
      unless defined_icons.include?(name)
        errors << "#{tpl}: unknown icon name '#{name}' (not defined in #{icon_defs_path})"
      end
    end
  end
end

# 8. Validate agent discoverability files (llms.txt, llms-full.txt, resume.json, .well-known/ard.json)
%w[llms.txt llms-full.txt].each do |md_name|
  md_path = File.join(SITE_DIR, md_name)
  next unless File.file?(md_path)

  content = File.read(md_path)
  if content.match?(/\{\{|\}\}|\{%|%\}/)
    errors << "#{md_path}: contains unrendered Liquid template syntax"
  end
  unless content.match?(/^#\s+\S/)
    errors << "#{md_path}: missing required H1 header"
  end
  if md_name == "llms.txt" && !content.match?(/\[[^\]]+\]\(https?:\/\/[^)]+\)/)
    errors << "#{md_path}: missing Markdown links"
  end
end

resume_json_path = File.join(SITE_DIR, "resume.json")
if File.file?(resume_json_path)
  begin
    resume = JSON.parse(File.read(resume_json_path))
    unless resume.is_a?(Hash) && resume.dig("basics", "name").is_a?(String) && resume["work"].is_a?(Array) && resume["skills"].is_a?(Array)
      errors << "#{resume_json_path}: missing required JSON Resume fields (basics.name, work, skills)"
    end
  rescue JSON::ParserError => e
    errors << "#{resume_json_path}: invalid JSON (#{e.message.lines.first.strip})"
  end
end

ard_path = File.join(SITE_DIR, ".well-known/ard.json")
if File.file?(ard_path)
  begin
    ard = JSON.parse(File.read(ard_path))
    entries = ard.is_a?(Hash) ? ard["entries"] : nil
    if !entries.is_a?(Array) || entries.empty?
      errors << "#{ard_path}: expected non-empty entries array"
    else
      entries.each_with_index do |entry, idx|
        prefix = "#{ard_path}: entries[#{idx}]"
        unless entry.is_a?(Hash)
          errors << "#{prefix} must be an object"
          next
        end
        unless entry["identifier"].is_a?(String) && entry["identifier"].match?(/\Aurn:air:[a-zA-Z0-9.-]+(:[a-zA-Z0-9._-]+)+\z/)
          errors << "#{prefix}: invalid ARD identifier URN (#{entry['identifier'].inspect})"
        end
        errors << "#{prefix}: missing displayName" if entry["displayName"].to_s.strip.empty?
        errors << "#{prefix}: missing type" if entry["type"].to_s.strip.empty?
        has_url = entry.key?("url") && !entry["url"].to_s.strip.empty?
        has_data = entry.key?("data") && !entry["data"].nil?
        unless has_url ^ has_data
          errors << "#{prefix}: must specify exactly one of 'url' or 'data'"
        end
        if has_url && site_url.start_with?("https://") && entry["url"].start_with?("#{site_url}/")
          target_path = URI.parse(entry["url"]).path
          unless local_target_exists?(target_path)
            errors << "#{prefix}: url target missing in #{SITE_DIR}/: #{entry['url']}"
          end
        end
        queries = entry["representativeQueries"]
        unless queries.is_a?(Array) && queries.length.between?(2, 5) && queries.all? { |q| q.is_a?(String) && !q.strip.empty? }
          errors << "#{prefix}: representativeQueries must be an array of 2 to 5 non-empty strings"
        end
      end
    end
  rescue JSON::ParserError => e
    errors << "#{ard_path}: invalid JSON (#{e.message.lines.first.strip})"
  end
end

# 9. Guard Gemfile.lock against dropping Cloudflare's precompiled binary platform
if File.file?("Gemfile.lock")
  lockfile = File.read("Gemfile.lock")
  platforms_section = lockfile[/^PLATFORMS\n(.*?)(?:\n\n|\z)/m, 1].to_s
  unless platforms_section.match?(/^\s+x86_64-linux-gnu\s*$/)
    errors << "Gemfile.lock: missing x86_64-linux-gnu platform (required for precompiled gems on Cloudflare Pages)"
  end
end

unless errors.empty?
  warn "Validation failed with #{errors.length} error(s):\n"
  warn errors.map { |e| "  - #{e}" }.join("\n")
  exit 1
end

puts "Site validation passed (#{html_files.length} HTML, #{css_files.length} CSS, sitemap, robots, icons, lockfile)."

#!/usr/bin/env ruby
# Copyright (C) 2012-2014 Paul Twohey.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'net/http'
require 'rexml/document'
require 'English'
require 'tempfile'

###
### Configuration variables
###
# Eclipse version. This is where you can customize the binary to install.
ECLIPSE_VERSION_BASE = '/technology/epp/downloads/release/luna/SR1/eclipse-jee-luna-SR1'

# Plugins to install. 
PLUGINS = []
PLUGINS << { pkg: 'AnyEditTools.feature.group', url: 'http://andrei.gmxhome.de/eclipse/' }
PLUGINS << { pkg: 'ch.acanda.eclipse.pmd.feature.feature.group', url: 'http://www.acanda.ch/eclipse-pmd/release/latest' }
PLUGINS << { pkg: 'com.mountainminds.eclemma.feature.feature.group', url: 'http://update.eclemma.org/' }
PLUGINS << { pkg: 'org.testng.eclipse.feature.group', url: 'http://beust.com/eclipse' }

gatekeeper = false

## Detect which platform we are installing on.
type = "#{`uname`.strip} #{`uname -m`.strip}"
puts "*** Detected #{type}"
case type 
when "Darwin x86_64"
  ECLIPSE_VERSION = "#{ECLIPSE_VERSION_BASE}-macosx-cocoa-x86_64.tar.gz"
  gatekeeper = true
when "Linux x86_64"
  ECLIPSE_VERSION = "#{ECLIPSE_VERSION_BASE}-linux-gtk-x86_64.tar.gz"
when /Linux i(386|486|586|686)/
  ECLIPSE_VERSION = "#{ECLIPSE_VERSION_BASE}-linux-gtk.tar.gz"
else
  $stderr.puts "ERROR: Unsupported install type: #{type}"
  exit 1
end


# Internal workings of the eclipse.org website.
SHA_BASE_URL = 'http://www.eclipse.org/downloads/sums.php'
DOWNLOAD_BASE_URL = 'http://www.eclipse.org/downloads/download.php'


def check_err(response, msg)
  return if response.is_a? Net::HTTPSuccess
  $stderr.puts "ERROR #{msg}"
  exit 1
end

def run_and_check_err(cmd)
  out = `#{cmd}`
  return out if $CHILD_STATUS.success?
  $stderr.puts "*** ERROR Command execution failed"
  $stderr.puts "Command: #{cmd}"
  $stderr.puts " Exited: #{$CHILD_STATUS.exitstatus}"
  exit 1
end

# Given a list of plugins, return a list of plugins which
# are already installed in eclipse/eclipse.
def filter_installed_plugins(plugins)
   out = run_and_check_err('./eclipse/eclipse -nosplash -application org.eclipse.equinox.p2.director -listInstalledRoots')
  # There are two types of plugins listed, just names, or names with versions
  missing = plugins.clone
  out.lines.each do |line|
    next if line.start_with? "Operation completed"
    plugins.each do |package|
      pkg = package[:pkg]
      missing.delete(package) if line.start_with? pkg
    end
  end

  return missing
end

# Download the supplied Eclipse version from a mirror supplied on
# eclipse.org while checking that it has the expected hash.
def download_eclipse(eclipse_version)
  # Get the SHA-1 hash to verify
  puts "*** Getting SHA-1 hash"

  params = { :file => eclipse_version, :type => "sha1" }
  uri = URI(SHA_BASE_URL)
  uri.query = URI.encode_www_form(params)
  response = Net::HTTP.get_response(uri)
  check_err(response, "Cannot download SHA-1 hash")
  expected_hash = response.body.split.first
  puts "*** SHA-1 hash is #{expected_hash}"

  # Get a list of mirrors
  puts "*** Getting list of mirrors"
  uri = URI(DOWNLOAD_BASE_URL)
  params = { :file => eclipse_version, :protocol => 'http', :format => 'xml' }
  uri.query = URI.encode_www_form(params)
  response = Net::HTTP.get_response(uri)
  check_err(response, "Cannot download Eclpse mirror list")

  # Choose a random mirror
  mirrors = []
  doc = REXML::Document.new(response.body)
  doc.elements.each("mirrors/mirror") { |e| mirrors << e.attribute("url").to_s }
  puts "** #{mirrors.size} mirrors"
  url = mirrors[ Kernel.rand(mirrors.size) ]
  
  # Download the eclipse binary
  puts "*** Downloading from mirror"
  puts "** #{url}"
  tar_file = File.basename eclipse_version
  run_and_check_err("curl #{url} > #{tar_file}")

  # Check the SHA-1 hash
  actual_hash = run_and_check_err("shasum #{tar_file}").split.first
  if expected_hash != actual_hash then
    $stderr.puts "*** ERROR SHA-1 CHECKSUMS DO NOT MATCH, POSSIBLE MALICIOUS ACTIVITY"
    $stderr.puts "#{expected_hash} Expected"
    $stderr.puts "#{actual_hash} Hash of downloaded file #{tar_file}"
    exit 1
  end
  puts "*** SHA-1 hash passes"

  # Untar downloaded file
  puts "*** Untaring file to create installation"
  run_and_check_err("tar jxf #{tar_file}")

  puts "*** Removing tar file"
  run_and_check_err("rm #{tar_file}")
end

# Install the plugins we want. To make matters simpler, the plugins are
# installed one at a time, and are tagged between each installation in
# order to provide some measure of debuggability if (when) things go wrong.
def install_plugins(plugins)
  puts "*** Installing #{plugins.size} plugins"

  puts "** Checking existing plugins"
  not_installed = filter_installed_plugins(plugins)
  puts "** #{plugins.size - not_installed.size} plugins installed. Installing remaining #{not_installed.size}"

  not_installed.each do |package|
    pkg = package[:pkg]
    url = package[:url]
    puts "** Installing #{pkg} from #{url}"
    human_name = pkg.split('/').first
    cmd = <<END
./eclipse/eclipse -nosplash -application org.eclipse.equinox.p2.director \
 -repository '#{url}' \
 -installIU '#{pkg}' \
 -tag #{human_name}
END
    out = run_and_check_err(cmd)
    puts out
    still_not_installed = filter_installed_plugins([ package ])
    if still_not_installed.size > 0 then
      $stderr.puts "ERROR #{package[:pkg]} did not install correctly"
      exit 1
    end
  end
end


###
### Run the installation
###
if !File.directory?('eclipse')
  download_eclipse(ECLIPSE_VERSION)
else
  puts "*** Eclipse already downloaded, skipping downloading again"
end

if gatekeeper then
  `spctl -a eclipse/Eclipse.app`
  if $?.success? then
    puts "*** Gatekeeper already configured to allow eclipse to run"
  else
    puts "*** configuring Gatekeeper to allow eclipse to run"
    run_and_check_err('spctl --add --label "Eclipse" eclipse/Eclipse.app')
  end
end

install_plugins(PLUGINS)

puts "*** Done"

#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates tmux-macos-net.rb by patching base/tmux.rb

base_path = File.join(__dir__, "..", "base", "tmux.rb")
output_path = File.join(__dir__, "..", "Formula", "tmux-macos-net.rb")

unless File.exist?(base_path)
  puts "Error: base/tmux.rb not found"
  exit 1
end

def indent_level(line)
  line[/^\s*/].length
end

def generate_custom_install
  <<-RUBY
  def install
    system "sh", "autogen.sh" if build.head?

    # Embed Info.plist so macOS can track Local Network Privacy consent.
    if OS.mac?
      (buildpath/"Info.plist").write <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.github.tmux.macosnet</string>
            <key>CFBundleName</key>
            <string>tmux-macos-net</string>
            <key>CFBundleVersion</key>
            <string>\#{version}</string>
            <key>NSLocalNetworkUsageDescription</key>
            <string>tmux needs access to the local network to allow spawned applications to connect to local network resources.</string>
            <key>NSBonjourServices</key>
            <array>
                <string>_http._tcp</string>
                <string>_ssh._tcp</string>
                <string>_sftp-ssh._tcp</string>
                <string>_smb._tcp</string>
            </array>
        </dict>
        </plist>
      PLIST
      ENV.append "LDFLAGS", "-Wl,-sectcreate,__TEXT,__info_plist,\#{buildpath}/Info.plist"
    end

    args = %W[
      --enable-sixel
      --sysconfdir=\#{etc}
      --enable-utf8proc
    ]
    args << "--with-TERM=screen-256color" if OS.mac? && MacOS.version < :sonoma

    system "./configure", *args, *std_configure_args
    system "make", "install"

    system "codesign", "-s", "-", "-f", "--identifier", "com.github.tmux.macosnet", bin/"tmux" if OS.mac?

    pkgshare.install "example_tmux.conf"
    bash_completion.install resource("completion")
  end

  RUBY
end

def generate_custom_caveats
  <<-RUBY
  def caveats
    <<~EOS
      tmux-macos-net is installed as `tmux` and includes an embedded Info.plist
      for Local Network Privacy support on macOS Sequoia+.

      To use the LaunchAgent service (recommended):
        brew services start tmux-macos-net

      Then from any SSH session, create a new session:
        tmux new

      Or attach to an existing session:
        tmux attach

      On first local network access, macOS will prompt for permission.
      Grant it, and all future SSH sessions will have local network access.

      The service runs as a LaunchAgent, making tmux self-responsible
      instead of inheriting responsibility from the SSH session.
    EOS
  end

  RUBY
end

def generate_service_block
  <<-RUBY
  service do
    run [opt_bin/"tmux", "-D"]
    keep_alive true
    process_type :interactive
    environment_variables(
      "PATH"    => "/usr/bin:/bin:/usr/sbin:/sbin:\#{HOMEBREW_PREFIX}/bin:\#{HOMEBREW_PREFIX}/sbin",
      "TERM"    => "screen-256color",
      "HOME"    => Dir.home,
      "LANG"    => "en_US.UTF-8",
      "TMUX_TMPDIR" => "/tmp",
    )
    log_path "/tmp/tmux-server.log"
    error_log_path "/tmp/tmux-server.err"
  end

  RUBY
end

# Main processing
lines = File.readlines(base_path)
output = []
skip_indent = nil

output << "# frozen_string_literal: true" << "\n"

lines.each do |line|
  # When `skip_indent` is set, skips all lines indented more than that amount.
  unless skip_indent.nil?
    next if line.strip.empty?
    next if indent_level(line) > skip_indent

    skip_indent = nil

    next
  end

  next if /^# frozen_string_literal: true$/.match?(line)

  # Class name
  if /^class Tmux < Formula$/.match?(line)
    output << "class TmuxMacosNet < Formula" << "\n"
    next
  end

  # Desc - we'll add conflicts_with after homepage
  if /^  desc "Terminal multiplexer"$/.match?(line)
    output << '  desc "Terminal multiplexer with macOS Local Network Privacy support"' << "\n"
    next
  end

  # Add conflicts_with after license (before livecheck/head)
  if /^  license /.match?(line)
    output << line
    output << '  conflicts_with "tmux", because: "both install `tmux` binary"' << "\n"
    next
  end

  # Remove bottle do
  if /^  bottle do$/.match?(line)
    skip_indent = indent_level(line)
    next
  end

  # Skip old install and caveats
  if /^  def install$/.match?(line)
    output << generate_custom_install
    skip_indent = indent_level(line)
    next
  end

  if /^  def caveats$/.match?(line)
    # Replace caveats
    output << generate_custom_caveats
    # Also output service block here (it doesn't exist in the base)
    output << generate_service_block
    # Skip until end of caveats
    skip_indent = indent_level(line)
    next
  end

  output << line
end

File.write(output_path, output.join)
puts "Generated: #{output_path}"

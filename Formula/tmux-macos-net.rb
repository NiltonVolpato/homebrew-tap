# tmux-macos-net: tmux with Local Network Privacy support for macOS
#
# This formula builds tmux with an embedded Info.plist and proper code signing
# to enable Local Network Privacy consent on macOS Sequoia+.
#
# The key issue this solves: When tmux is spawned from SSH, it inherits the sshd
# as its "responsible process". When SSH disconnects, tmux loses network access.
# By embedding Info.plist and running as a service, tmux can request its own
# Local Network permission.
#
# Based on the discovery that combining Info.plist + launchd service fixes
# the "no route to host" error for local network access in tmux.
#
# NOTE: This formula is based on core tmux. When core tmux updates,
# this formula should be updated to match (copy url, sha256, dependencies).
# Check: https://github.com/Homebrew/homebrew-core/blob/master/Formula/t/tmux.rb
#
# Usage:
#   brew install niltonvolpato/tap/tmux-macos-net
#   brew services start tmux-macos-net
#
# Then from any SSH session:
#   tmux new

class TmuxMacosNet < Formula
  desc "Terminal multiplexer with macOS Local Network Privacy support"
  homepage "https://tmux.github.io/"
  url "https://github.com/tmux/tmux/releases/download/3.6a/tmux-3.6a.tar.gz"
  sha256 "b6d8d9c76585db8ef5fa00d4931902fa4b8cbe8166f528f44fc403961a3f3759"
  license "ISC"
  revision 1

  livecheck do
    url :stable
    regex(/v?(\d+(?:\.\d+)+[a-z]?)/i)
    strategy :github_latest
  end

  head do
    url "https://github.com/tmux/tmux.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "libtool" => :build
  end

  depends_on "pkgconf" => :build
  depends_on "libevent"
  depends_on "ncurses"
  depends_on "utf8proc"

  uses_from_macos "bison" => :build # for yacc

  # Conflicts with core tmux - they install the same binary name
  conflicts_with "tmux", because: "both install `tmux` binary"

  resource "completion" do
    url "https://raw.githubusercontent.com/imomaliev/tmux-bash-completion/8da7f797245970659b259b85e5409f197b8afddd/completions/tmux"
    sha256 "4e2179053376f4194b342249d75c243c1573c82c185bfbea008be1739048e709"
  end

  def install
    system "sh", "autogen.sh" if build.head?

    # Embed Info.plist so macOS can track Local Network Privacy consent.
    # This is the critical fix for the "no route to host" error in tmux
    # when accessing local network resources after SSH disconnects.
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
            <string>#{version}</string>
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
      ENV.append "LDFLAGS", "-Wl,-sectcreate,__TEXT,__info_plist,#{buildpath}/Info.plist"
    end

    args = %W[
      --enable-sixel
      --sysconfdir=#{etc}
      --enable-utf8proc
    ]

    # tmux finds the `tmux-256color` terminfo provided by our ncurses
    # and uses that as the default `TERM`, but this causes issues for
    # tools that link with the very old ncurses provided by macOS.
    args << "--with-TERM=screen-256color" if OS.mac? && MacOS.version < :sonoma

    system "./configure", *args, *std_configure_args
    system "make", "install"

    # Re-sign with the bundle identifier from the embedded Info.plist so
    # macOS associates Local Network Privacy consent with this binary.
    if OS.mac?
      system "codesign", "-s", "-", "-f", "--identifier", "com.github.tmux.macosnet", bin/"tmux"
    end

    pkgshare.install "example_tmux.conf"
    bash_completion.install resource("completion")
  end

  # Launchd service to run tmux server in background
  # This ensures tmux is self-responsible and can request its own permissions
  service do
    run [opt_bin/"tmux", "-D"]  # -D = run in foreground (don't daemonize)
    keep_alive true
    process_type :interactive
    
    # Environment variables for the service
    environment_variables(
      "PATH" => "/usr/bin:/bin:/usr/sbin:/sbin:#{HOMEBREW_PREFIX}/bin:#{HOMEBREW_PREFIX}/sbin",
      "TERM" => "screen-256color",
      "HOME" => ENV["HOME"],
      "LANG" => "en_US.UTF-8",
      "TMUX_TMPDIR" => "/tmp"
    )
    
    # Log files for debugging
    log_path "/tmp/tmux-server.log"
    error_log_path "/tmp/tmux-server.err"
  end

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

      If you already have the core tmux installed:
        brew unlink tmux
        brew link tmux-macos-net

      To switch back to core tmux:
        brew unlink tmux-macos-net
        brew link tmux
    EOS
  end

  test do
    system bin/"tmux", "-V"

    require "pty"

    socket = testpath/tap.user
    PTY.spawn bin/"tmux", "-S", socket, "-f", File::NULL
    sleep 10

    assert_path_exists socket
    assert_predicate socket, :socket?
    assert_equal "no server running on #{socket}", shell_output("#{bin}/tmux -S#{socket} list-sessions 2>&1", 1).chomp
  end
end

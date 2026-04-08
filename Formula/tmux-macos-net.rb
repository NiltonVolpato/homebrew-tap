# typed: strict
# frozen_string_literal: true

class TmuxMacosNet < Formula
  desc "Terminal multiplexer with macOS Local Network Privacy support"
  homepage "https://tmux.github.io/"
  url "https://github.com/tmux/tmux/releases/download/3.6a/tmux-3.6a.tar.gz"
  sha256 "b6d8d9c76585db8ef5fa00d4931902fa4b8cbe8166f528f44fc403961a3f3759"
  license "ISC"
  compatibility_version 1

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

  conflicts_with "tmux", because: "both install `tmux` binary"

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
    args << "--with-TERM=screen-256color" if OS.mac? && MacOS.version < :sonoma

    system "./configure", *args, *std_configure_args
    system "make", "install"

    system "codesign", "-s", "-", "-f", "--identifier", "com.github.tmux.macosnet", bin/"tmux" if OS.mac?

    pkgshare.install "example_tmux.conf"
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
    EOS
  end

  service do
    run [opt_bin/"tmux", "-D"]
    keep_alive true
    process_type :interactive
    environment_variables(
      PATH:    "#{HOMEBREW_PREFIX}/bin:#{HOMEBREW_PREFIX}/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
      USER:    ENV["USER"],
      LOGNAME: ENV["USER"],
      TERM:    "xterm-256color",
      HOME:    Dir.home,
      LANG:    "en_US.UTF-8",
    )
    log_path "/tmp/tmux-server.log"
    error_log_path "/tmp/tmux-server.err"
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

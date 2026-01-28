class Mosh < Formula
  desc "Remote terminal application"
  homepage "https://mosh.org"
  url "https://github.com/mobile-shell/mosh/releases/download/mosh-1.4.0/mosh-1.4.0.tar.gz"
  sha256 "872e4b134e5df29c8933dff12350785054d2fd2839b5ae6b5587b14db1465ddd"
  license "GPL-3.0-or-later"
  revision 34

  no_autobump! because: :requires_manual_review

  head do
    url "https://github.com/mobile-shell/mosh.git", branch: "master"

    depends_on "autoconf" => :build
    depends_on "automake" => :build
  end

  depends_on "pkgconf" => :build
  depends_on "protobuf"

  uses_from_macos "ncurses"
  uses_from_macos "zlib"

  on_macos do
    depends_on "tmux" => :build # for `make check`
  end

  on_linux do
    depends_on "openssl@3" # Uses CommonCrypto on macOS
  end

  def install
    # https://github.com/protocolbuffers/protobuf/issues/9947
    ENV.append_to_cflags "-DNDEBUG"
    # Avoid over-linkage to `abseil`.
    ENV.append "LDFLAGS", "-Wl,-dead_strip_dylibs" if OS.mac?

    # Embed Info.plist so macOS can track Local Network Privacy consent.
    # Without this, mosh (and all its child processes) are blocked from
    # accessing the local network on macOS Sequoia+.
    if OS.mac?
      (buildpath/"Info.plist").write <<~PLIST
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>org.mosh.mosh</string>
            <key>CFBundleName</key>
            <string>mosh</string>
            <key>CFBundleVersion</key>
            <string>#{version}</string>
            <key>NSLocalNetworkUsageDescription</key>
            <string>mosh needs access to the local network to manage terminal sessions.</string>
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

    # teach mosh to locate mosh-client without referring
    # PATH to support launching outside shell e.g. via launcher
    inreplace "scripts/mosh.pl", "'mosh-client", "'#{bin}/mosh-client"

    if build.head?
      # Prevent mosh from reporting `-dirty` in the version string.
      inreplace "Makefile.am", "--dirty", "--dirty=-Homebrew"
      system "./autogen.sh"
    elsif version <= "1.4.0" # remove `elsif` block and `else` at version bump.
      # Keep C++ standard in sync with abseil.rb.
      # Use `gnu++17` since Mosh allows use of GNU extensions (-std=gnu++11).
      ENV.append "CXXFLAGS", "-std=gnu++17"
    else # Remove `else` block at version bump.
      odie "Install method needs updating!"
    end

    # `configure` does not recognise `--disable-debug` in `std_configure_args`.
    system "./configure", "--prefix=#{prefix}", "--enable-completion", "--disable-silent-rules"
    system "make", "install"

    # Re-sign with the bundle identifier from the embedded Info.plist so
    # macOS associates Local Network Privacy consent with these binaries.
    if OS.mac?
      system "codesign", "-s", "-", "-f", "--identifier", "org.mosh.mosh", bin/"mosh-client"
      system "codesign", "-s", "-", "-f", "--identifier", "org.mosh.mosh", bin/"mosh-server"
    end
  end

  test do
    system bin/"mosh-client", "-c"
  end
end

class AwdlSentinel < Formula
  desc "Kernel-level sentinel to suppress AWDL-caused WiFi latency trashing."
  homepage "https://github.com/NiltonVolpato/awdl-sentinel/"
  url "https://github.com/NiltonVolpato/awdl-sentinel/archive/refs/tags/v0.0.0.tar.gz"
  sha256 "a1fbf7de348831d3c677c1b555b142893beda9c2e6fd3ea82084343e1af78c21"
  head "https://github.com/NiltonVolpato/awdl-sentinel.git"
  license "Apache-2.0"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "make"

    bin.install "build/awdl-sentinel"
    prefix.install "build/AWDL Sentinel.app"
  end

  service do
    run [opt_bin/"awdl-sentinel"]
    require_root true
    keep_alive true
    log_path var/"log/awdl-sentinel.log"
    error_log_path var/"log/awdl-sentinel.log"
  end

  test do
    assert_predicate bin/"awdl-sentinel", :exist?
  end
end

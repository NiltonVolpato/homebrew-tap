class AwdlSentinel < Formula
  desc "Kernel-level sentinel to suppress AWDL-caused WiFi latency trashing"
  homepage "https://github.com/NiltonVolpato/awdl-sentinel/"
  url "https://github.com/NiltonVolpato/awdl-sentinel/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "0ac3b1af541d273d0f15b3f01c43ad1b2a6e71fc076dadbbad070eafb3288212"
  license "Apache-2.0"
  head "https://github.com/NiltonVolpato/awdl-sentinel.git", using: :git, branch: "main"

  depends_on xcode: ["14.0", :build]
  depends_on :macos

  def install
    system "make"

    bin.install "build/awdl-sentinel"
    prefix.install "build/AWDL Sentinel.app"
  end

  service do
    run [opt_bin/"awdl-sentinel", "daemon"]
    require_root true
    keep_alive true
    log_path var/"log/awdl-sentinel.log"
    error_log_path var/"log/awdl-sentinel.log"
  end

  test do
    assert_path_exists bin/"awdl-sentinel"
  end
end

# frozen_string_literal: true

require "test_helper"
require "socket"

class ClamavScannerPocTest < ActiveSupport::TestCase
  def self.clamav_available?
    return false unless ENV["CLAMAV_POC_ENABLED"] == "1"

    native_scanner? || docker_clamd?
  end

  def self.native_scanner?
    system("command -v clamscan >/dev/null 2>&1")
  end

  def self.docker_clamd?
    port_open?(ENV.fetch("CLAMAV_POC_PORT", "3310"))
  end

  def self.port_open?(port)
    socket = Socket.tcp("127.0.0.1", port.to_i, connect_timeout: 2)
    socket.close
    true
  rescue StandardError
    false
  end

  def setup
    skip "CLAMAV_POC_ENABLED=1 with clamscan or clamd required" unless self.class.clamav_available?
    @prior_command = ENV["STORAGE_SCAN_COMMAND"]
    ENV["STORAGE_SCAN_COMMAND"] = if self.class.native_scanner?
      ENV.fetch("CLAMAV_POC_SCAN_COMMAND", "scripts/clamav_local_scan.sh")
    else
      ENV.fetch("CLAMAV_POC_SCAN_COMMAND", "scripts/clamav_poc_scan.sh")
    end
  end

  def teardown
    ENV["STORAGE_SCAN_COMMAND"] = @prior_command
  end

  test "clean synthetic file passes external scanner" do
    result = Storage::MalwareScanner.scan(StringIO.new("hello clean content #{SecureRandom.hex}"))
    assert_equal :clean, result.status
  end

  test "eicar is rejected by external scanner path" do
    result = Storage::MalwareScanner.scan(StringIO.new(Storage::MalwareScanner::EICAR_TEST_STRING))
    assert_equal :rejected, result.status
  end

  test "scanner command failure is error not clean" do
    ENV["STORAGE_SCAN_COMMAND"] = "false"
    result = Storage::MalwareScanner.scan(StringIO.new("benign"))
    assert_equal :error, result.status
  end
end

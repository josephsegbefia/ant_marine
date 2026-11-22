# frozen_string_literal: true

require "test_helper"

class InfrastructureWorkerSmokeJobTest < ActiveJob::TestCase
  test "smoke job writes cache marker" do
    token = "test-token"
    Infrastructure::WorkerSmokeJob.perform_now(token)

    assert AuditEvent.exists?(event_type: "infrastructure.worker_smoke", metadata: { "smoke_ref" => token, "source" => "solid_queue" })
  end
end

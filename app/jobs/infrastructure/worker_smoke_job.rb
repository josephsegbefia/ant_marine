# frozen_string_literal: true

module Infrastructure
  class WorkerSmokeJob < ApplicationJob
    queue_as :default

    self.log_arguments = false

    def perform(token)
      AuditEvent.record!(
        event_type: "infrastructure.worker_smoke",
        metadata: { smoke_ref: token, source: "solid_queue" }
      )
    end
  end
end

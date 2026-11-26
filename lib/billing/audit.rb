# frozen_string_literal: true

module Billing
  module Audit
    module_function

    def record!(event_type:, actor_membership:, subject:, metadata: {})
      AuditEvent.record!(
        event_type: event_type,
        organization: subject.respond_to?(:operating_organization) ? subject.operating_organization : actor_membership.organization,
        actor_membership: actor_membership,
        subject: subject,
        metadata: metadata.merge(
          "mode" => (subject.respond_to?(:mode) ? subject.mode : "simulated"),
          "simulated" => true
        )
      )
    end

    def created(invoice:, actor_membership:)
      record!(event_type: "invoice.created", actor_membership: actor_membership, subject: invoice,
              metadata: { "reference_number" => invoice.reference_number, "total_cents" => invoice.total_cents })
    end

    def updated(invoice:, actor_membership:)
      record!(event_type: "invoice.updated", actor_membership: actor_membership, subject: invoice,
              metadata: { "reference_number" => invoice.reference_number, "total_cents" => invoice.total_cents })
    end

    def issued(invoice:, actor_membership:)
      record!(event_type: "invoice.issued", actor_membership: actor_membership, subject: invoice,
              metadata: { "reference_number" => invoice.reference_number, "total_cents" => invoice.total_cents,
                          "artifact_checksum_sha256" => invoice.artifact_checksum_sha256 })
    end

    def released(invoice:, release:, actor_membership:)
      record!(event_type: "invoice.released", actor_membership: actor_membership, subject: invoice,
              metadata: { "reference_number" => invoice.reference_number, "invoice_release_id" => release.id })
    end

    def release_revoked(invoice:, release:, actor_membership:)
      record!(event_type: "invoice.release_revoked", actor_membership: actor_membership, subject: invoice,
              metadata: { "reference_number" => invoice.reference_number, "invoice_release_id" => release.id })
    end

    def payment_recorded(invoice:, payment:, actor_membership:)
      record!(event_type: "payment.recorded", actor_membership: actor_membership, subject: invoice,
              metadata: { "payment_record_id" => payment.id, "amount_cents" => payment.amount_cents })
    end

    def payment_reversed(invoice:, payment:, reversal:, actor_membership:)
      record!(event_type: "payment.reversed", actor_membership: actor_membership, subject: invoice,
              metadata: { "payment_record_id" => payment.id, "payment_reversal_id" => reversal.id,
                          "amount_cents" => reversal.amount_cents })
    end

    def voided(invoice:, actor_membership:)
      record!(event_type: "invoice.voided", actor_membership: actor_membership, subject: invoice,
              metadata: { "reference_number" => invoice.reference_number, "void_reason" => invoice.void_reason })
    end

    def downloaded(invoice:, actor_membership:)
      record!(event_type: "invoice.downloaded", actor_membership: actor_membership, subject: invoice,
              metadata: { "reference_number" => invoice.reference_number })
    end
  end
end

# frozen_string_literal: true

module Billing
  class Issue
    Result = Data.define(:invoice)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      CreateDraft.available?
    end

    def self.call(membership:, invoice:, confirmation: false)
      new(membership: membership).call(invoice: invoice, confirmation: confirmation)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(invoice:, confirmation:)
      raise Denied, "Simulated invoice issuance is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to issue this invoice." unless Billing::Access.can_issue?(@membership, invoice)
      raise Error, "Confirm that this simulated invoice should be issued." unless ActiveModel::Type::Boolean.new.cast(confirmation)
      raise InvalidState, "Only draft invoices can be issued." unless invoice.draft?
      raise InvalidState, "Add invoice items before issuing." if invoice.invoice_line_items.empty?
      raise InvalidState, "Set a due date before issuing." if invoice.due_on.blank?

      issued = nil
      Invoice.transaction do
        project = Project.lock.find(invoice.project_id)
        locked = Invoice.lock.find(invoice.id)
        raise InvalidState, "Only draft invoices can be issued." unless locked.draft?
        raise InvalidState, "Only simulated projects can receive development invoices." unless project.simulated?

        # Re-verify commercial source integrity.
        if locked.quote_revision_id != project.quote_revision_id ||
           locked.quote_response_id != project.quote_response_id ||
           locked.commercial_snapshot["total_cents"].to_i != project.commercial_snapshot["total_cents"].to_i
          raise InvalidState, "The commercial source no longer matches this project. Recreate the draft."
        end

        Billing::Capacity.assert_issuable!(
          project: project,
          amount_cents: locked.total_cents,
          excluding_invoice_id: locked.id
        )

        pdf_bytes = Billing::PdfRenderer.render(invoice: locked, draft: false)
        asset = Billing::ArtifactStore.persist_pdf!(
          membership: @membership,
          organization: locked.operating_organization,
          pdf_bytes: pdf_bytes,
          filename: "#{locked.reference_number}.pdf"
        )

        locked.update!(
          issue_status: "issued",
          issued_at: Time.current,
          issued_by_membership: @membership,
          issue_on: locked.issue_on || Time.zone.today,
          storage_asset: asset,
          artifact_checksum_sha256: asset.checksum_sha256
        )

        audit = Billing::Audit.issued(invoice: locked, actor_membership: @membership)
        Notifications::StaffPublisher.invoice_issued(invoice: locked, audit_event: audit, actor: @membership)
        issued = locked
      end

      Result.new(invoice: issued.reload)
    end
  end
end

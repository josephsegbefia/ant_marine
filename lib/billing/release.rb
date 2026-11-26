# frozen_string_literal: true

module Billing
  class Release
    Result = Data.define(:invoice, :release)

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
      raise Denied, "Simulated invoice release is not available in production yet." unless self.class.available?
      raise Denied, "You are not allowed to release this invoice." unless Billing::Access.can_release?(@membership, invoice)
      raise Error, "Confirm that this exact issued invoice should be shared with the client." unless ActiveModel::Type::Boolean.new.cast(confirmation)
      raise InvalidState, "Issue the invoice before releasing it." unless invoice.issued?
      raise InvalidState, "The issued PDF must be ready before release." if invoice.artifact_checksum_sha256.blank?

      release_record = nil
      Invoice.transaction do
        locked = Invoice.lock.find(invoice.id)
        raise InvalidState, "Issue the invoice before releasing it." unless locked.issued?

        active = locked.invoice_releases.active.lock.first
        return Result.new(invoice: locked, release: active) if active

        release_record = InvoiceRelease.create!(
          invoice: locked,
          client_organization: locked.client_organization,
          released_by_membership: @membership,
          released_at: Time.current,
          storage_asset_id: locked.storage_asset_id,
          artifact_checksum_sha256: locked.artifact_checksum_sha256
        )
        audit = Billing::Audit.released(invoice: locked, release: release_record, actor_membership: @membership)
        Notifications::StaffPublisher.invoice_released(invoice: locked, audit_event: audit, actor: @membership)
      end

      Result.new(invoice: invoice.reload, release: release_record)
    end
  end
end

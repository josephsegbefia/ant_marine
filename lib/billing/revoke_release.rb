# frozen_string_literal: true

module Billing
  class RevokeRelease
    Result = Data.define(:invoice, :release)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, invoice:, release:, reason:)
      new(membership: membership).call(invoice: invoice, release: release, reason: reason)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(invoice:, release:, reason:)
      raise Denied, "You are not allowed to revoke this invoice release." unless Billing::Access.can_release?(@membership, invoice)
      raise InvalidState, "That release does not belong to this invoice." unless release.invoice_id == invoice.id
      raise InvalidState, "This release is already revoked." if release.revoked?
      raise InvalidState, "Explain why client access is being withdrawn." if reason.to_s.strip.blank?

      Invoice.transaction do
        locked_release = InvoiceRelease.lock.find(release.id)
        raise InvalidState, "This release is already revoked." if locked_release.revoked?

        locked_release.update!(
          revoked_at: Time.current,
          revoked_by_membership: @membership,
          revocation_reason: reason.to_s.strip
        )
        Billing::Audit.release_revoked(invoice: invoice, release: locked_release, actor_membership: @membership)
        Result.new(invoice: invoice.reload, release: locked_release)
      end
    end
  end
end

# frozen_string_literal: true

module Billing
  module Capacity
    module_function

    def accepted_total_cents(project)
      snapshot = project.commercial_snapshot || {}
      snapshot["total_cents"].to_i
    end

    def issued_committed_cents(project, excluding_invoice_id: nil)
      scope = Invoice.where(project_id: project.id, issue_status: "issued")
      scope = scope.where.not(id: excluding_invoice_id) if excluding_invoice_id
      scope.sum(:total_cents)
    end

    def draft_reserved_cents(project, excluding_invoice_id: nil)
      scope = Invoice.where(project_id: project.id, issue_status: "draft")
      scope = scope.where.not(id: excluding_invoice_id) if excluding_invoice_id
      scope.sum(:total_cents)
    end

    def remaining_billable_cents(project, excluding_invoice_id: nil, include_drafts: false)
      committed = issued_committed_cents(project, excluding_invoice_id: excluding_invoice_id)
      committed += draft_reserved_cents(project, excluding_invoice_id: excluding_invoice_id) if include_drafts
      [ accepted_total_cents(project) - committed, 0 ].max
    end

    def assert_issuable!(project:, amount_cents:, excluding_invoice_id: nil)
      remaining = remaining_billable_cents(project, excluding_invoice_id: excluding_invoice_id, include_drafts: false)
      return remaining if amount_cents <= remaining

      raise Billing::Issue::InvalidState,
            "This invoice would exceed the accepted commercial amount. Remaining billable: #{Commercial::Money.display(remaining, project.commercial_snapshot['currency'])}."
    end
  end
end

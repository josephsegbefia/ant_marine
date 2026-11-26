# frozen_string_literal: true

module Billing
  module Dashboard
    Summary = Data.define(
      :currency, :issued_total_cents, :net_paid_cents, :outstanding_cents,
      :overdue_cents, :draft_count, :issued_count, :overdue_count
    )

    module_function

    def summaries_for(membership:, currency: nil)
      scope = scoped_invoices(membership)
      scope = scope.where(currency: currency) if currency.present?

      currencies = currency.present? ? [ currency ] : scope.distinct.pluck(:currency).sort
      currencies.map { |code| build_summary(scope.where(currency: code), code) }
    end

    def build_summary(scope, currency)
      issued = scope.issued
      issued_total = issued.sum(:total_cents)
      net_paid = PaymentRecord.where(invoice_id: issued.select(:id)).left_joins(:payment_reversal)
                              .where(payment_reversals: { id: nil }).sum(:amount_cents)
      outstanding = [ issued_total - net_paid, 0 ].max
      overdue_ids = issued.select { |inv| inv.overdue? }.map(&:id)
      overdue_cents = overdue_ids.sum { |id| Invoice.find(id).outstanding_cents }

      Summary.new(
        currency: currency,
        issued_total_cents: issued_total,
        net_paid_cents: net_paid,
        outstanding_cents: outstanding,
        overdue_cents: overdue_cents,
        draft_count: scope.draft.count,
        issued_count: issued.count,
        overdue_count: overdue_ids.size
      )
    end

    def scoped_invoices(membership)
      base = Invoice.simulated.for_operating_organization(membership.organization)
      perms = Authorization::EffectivePermissions.new(membership)
      return base if perms.allowed?("billing.view_all")
      return base.none unless perms.allowed?("billing.view")

      visible_project_ids = Project.for_operating_organization(membership.organization).select do |project|
        Billing::Access.project_visible?(membership, project)
      end.map(&:id)
      base.where(project_id: visible_project_ids)
    end
  end
end

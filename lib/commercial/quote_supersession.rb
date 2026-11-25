# frozen_string_literal: true

module Commercial
  # Supersession is explicit and narrow:
  # - approving version N retires earlier approved versions that were never sent;
  # - an earlier *issued* version stays the client's outstanding offer until version N is
  #   itself issued (accepted by the mail provider), or the quotation is withdrawn.
  module QuoteSupersession
    module_function

    def after_approval!(quote:, revision:)
      supersede!(quote.quote_revisions.where(revision_status: "approved").where.not(id: revision.id), by: revision)
    end

    def after_issue!(quote:, revision:)
      supersede!(quote.quote_revisions.where(revision_status: "issued").where.not(id: revision.id), by: revision)
    end

    def supersede!(scope, by:)
      now = Time.current
      scope.where(version_number: ...by.version_number).lock.order(:version_number).to_a.each do |earlier|
        earlier.update!(revision_status: "superseded", superseded_at: now, superseded_by_revision: by)
      end
    end
  end
end

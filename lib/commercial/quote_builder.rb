# frozen_string_literal: true

module Commercial
  class QuoteBuilder
    ATTEMPTS = 3

    def self.create!(organization:, membership:)
      attempts = 0
      begin
        attempts += 1
        Quote.transaction(requires_new: true) do
          quote = Quote.create!(
            organization: organization,
            reference_number: QuoteReference.generate!(organization: organization),
            created_by_membership: membership,
            updated_by_membership: membership,
            prospective_client: {}
          )
          revision = quote.quote_revisions.create!(
            version_number: 1,
            title: "",
            prepared_by_membership: membership,
            contributor_membership_ids: [ membership.id ]
          )
          quote.update!(current_revision: revision)
          AuditEvent.record!(
            event_type: "quote.created",
            organization: organization,
            actor_membership: membership,
            subject: quote,
            metadata: { reference_number: quote.reference_number }
          )
          quote
        end
      rescue ActiveRecord::RecordNotUnique
        retry if attempts < ATTEMPTS
        raise
      end
    end
  end
end

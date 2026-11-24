# frozen_string_literal: true

module Commercial
  class QuoteBuilder
    def self.create!(organization:, membership:)
      Quote.transaction do
        quote = Quote.create!(
          organization: organization,
          reference_number: QuoteReference.generate!(organization: organization),
          created_by_membership: membership,
          updated_by_membership: membership,
          prospective_client: {}
        )
        revision = quote.quote_revisions.create!(version_number: 1, title: "New quotation")
        quote.update!(current_revision: revision)
        quote
      end
    end
  end
end

# frozen_string_literal: true

module Commercial
  # Opens a new draft version of an approved or issued quotation. The earlier version
  # stays exactly as approved (and, if issued, remains the client's outstanding offer)
  # until the new version is itself approved or issued — see QuoteTransition.
  class QuoteRevisionCreator
    SOURCE_STATUSES = %w[approved_for_issuance issued].freeze
    COPIED_ATTRIBUTES = %w[title scope_description deliverables exclusions additional_requirements currency
                           payment_terms commercial_exclusions additional_conditions internal_notes].freeze

    class NotAllowed < QuoteTransition::InvalidTransition; end

    def self.create!(quote:, membership:, reason:, expected_version:)
      new(quote:, membership:, reason:, expected_version:).create!
    end

    def initialize(quote:, membership:, reason:, expected_version:)
      @quote = quote
      @membership = membership
      @reason = reason.to_s.strip
      @expected_version = expected_version.to_h.symbolize_keys
    end

    def create!
      raise QuoteTransition::InvalidTransition, "Explain why a new version is needed." if @reason.blank?
      if @reason.length > QuoteRevision::REVISION_REASON_LIMIT
        raise QuoteTransition::InvalidTransition, "Keep the reason under #{QuoteRevision::REVISION_REASON_LIMIT} characters."
      end

      Quote.transaction do
        @quote.lock!
        source = @quote.current_revision
        source&.lock!
        ensure_expected_version!(source)
        unless SOURCE_STATUSES.include?(@quote.status) && source&.version_frozen?
          raise NotAllowed, "A new version can only be created from an approved or issued quotation."
        end
        raise QuoteTransition::NotAuthorized, "You do not have permission to do that." unless authorized?

        revision = build_revision(source)
        @quote.update!(status: "draft", current_revision: revision, updated_by_membership: @membership)

        AuditEvent.record!(
          event_type: "quote.revision_created",
          organization: @quote.organization,
          actor_membership: @membership,
          subject: @quote,
          metadata: {
            reference_number: @quote.reference_number,
            version_number: revision.version_number,
            revision_id: revision.id,
            predecessor_version_number: source.version_number,
            predecessor_revision_id: source.id,
            predecessor_status: source.revision_status,
            reason: @reason
          }
        )
        revision
      end
    end

    private

      def ensure_expected_version!(source)
        current = source.present? &&
                  @expected_version[:revision_id].to_s == source.id.to_s &&
                  @expected_version[:lock_version].to_s == @quote.lock_version.to_s
        raise QuoteTransition::StaleVersion, QuoteTransition::STALE_MESSAGE unless current
      end

      def authorized?
        return false unless @membership&.status == "active" && @membership.user&.status == "active"

        QuotePolicy.new(@membership, @quote).create_revision?
      end

      def build_revision(source)
        revision = @quote.quote_revisions.build(
          source.attributes.slice(*COPIED_ATTRIBUTES).merge(
            version_number: @quote.quote_revisions.maximum(:version_number).to_i + 1,
            revision_status: "draft",
            valid_until: (source.valid_until if source.valid_until && source.valid_until >= Date.current),
            predecessor_revision: source,
            revision_reason: @reason,
            prepared_by_membership: @membership,
            contributor_membership_ids: [ @membership.id ]
          )
        )
        source.line_items.each do |item|
          revision.line_items.build(item.attributes.slice("position", "description", "quantity", "unit", "unit_price_cents"))
        end
        revision.save!
        revision
      end
  end
end

# frozen_string_literal: true

module Commercial
  class QuoteTransition
    class InvalidTransition < StandardError; end
    class NotAuthorized < InvalidTransition; end
    class StaleVersion < InvalidTransition; end

    class SeparationRequired < NotAuthorized
      def initialize(message = "You prepared or edited this version, so a different reviewer must approve it.")
        super
      end
    end

    class NotReady < InvalidTransition
      attr_reader :issues

      def initialize(issues)
        @issues = issues
        super("This quotation is not ready yet.")
      end
    end

    TRANSITIONS = {
      "submit_for_review" => { from: Quote::EDITABLE_STATUSES, to: "pending_review", revision: "pending_review", readiness: true },
      "return_for_correction" => { from: %w[pending_review], to: "returned_for_correction", revision: "draft",
                                   reason_required: true, reviewer_action: true },
      "approve" => { from: %w[pending_review], to: "approved_for_issuance", revision: "approved", freeze: true,
                     readiness: true, reviewer_action: true, independent_reviewer: true },
      "issue" => { from: %w[approved_for_issuance], to: "issued", revision: "issued", gated: true },
      "withdraw" => { from: %w[draft pending_review returned_for_correction approved_for_issuance issued], to: "withdrawn", revision: nil }
    }.freeze

    STATUS_MESSAGES = {
      "pending_review" => "This quotation is already waiting for review.",
      "approved_for_issuance" => "This quotation has already been approved.",
      "issued" => "This quotation has already been marked as issued.",
      "withdrawn" => "This quotation has been withdrawn.",
      "superseded" => "This quotation has been replaced by a newer version."
    }.freeze

    STALE_MESSAGE = "This quotation changed after you opened it. Nothing was changed. Review the current version and try again."
    UNATTRIBUTED_MESSAGE = "This version has no recorded preparer, so it cannot be approved. " \
                           "Return it for correction so it can be saved and submitted again."

    # Reviewer actions (approve, return for correction) must name the exact version the
    # reviewer looked at: expected_version: { revision_id:, lock_version: }.
    def self.apply!(quote:, action:, membership:, reason: nil, expected_version: nil)
      new(quote:, action:, membership:, reason:, expected_version:).apply!
    end

    def initialize(quote:, action:, membership:, reason: nil, expected_version: nil)
      @quote = quote
      @action = action.to_s
      @membership = membership
      @reason = reason.to_s.strip.presence
      @expected_version = expected_version&.to_h&.symbolize_keys
    end

    def apply!
      rule = TRANSITIONS.fetch(@action) { raise InvalidTransition, "Unknown quotation action." }

      Quote.transaction do
        @quote.lock!
        revision = @quote.current_revision
        revision&.lock!
        previous_status = @quote.status

        unless rule[:from].include?(previous_status)
          raise InvalidTransition, STATUS_MESSAGES.fetch(previous_status, "This quotation cannot do that in its current state.")
        end
        raise InvalidTransition, QuoteIssuance::UNAVAILABLE_MESSAGE if rule[:gated] && !QuoteIssuance.available?
        raise NotAuthorized, "You do not have permission to do that." unless actor_active? && permitted?(rule)
        ensure_current_version!(revision) if rule[:reviewer_action]
        ensure_independent_reviewer!(revision) if rule[:independent_reviewer]
        raise NotAuthorized, "You do not have permission to do that." unless authorized?
        raise InvalidTransition, "Explain what needs to be corrected." if rule[:reason_required] && @reason.nil?

        if rule[:readiness]
          issues = QuoteReadiness.check(@quote)
          raise NotReady, issues if issues.any?
        end

        @quote.update!(status: rule[:to], updated_by_membership: @membership)
        revision.update!(revision_attributes(rule, revision)) if revision && rule[:revision]
        superseded = @action == "approve" ? QuoteSupersession.after_approval!(quote: @quote, revision: revision) : []

        AuditEvent.record!(
          event_type: "quote.#{@action}",
          organization: @quote.organization,
          actor_membership: @membership,
          subject: @quote,
          metadata: {
            reference_number: @quote.reference_number,
            previous_status: previous_status,
            new_status: @quote.status,
            version_number: revision&.version_number,
            revision_id: revision&.id,
            prepared_by_membership_id: revision&.prepared_by_membership_id,
            submitted_by_membership_id: revision&.submitted_by_membership_id,
            total_cents: revision&.total_cents,
            currency: revision&.currency,
            reason: @reason,
            superseded_version_numbers: superseded.map(&:version_number).presence
          }.compact
        )
      end

      @quote
    rescue SeparationRequired
      record_refused_approval
      raise
    end

    private

      def actor_active?
        @membership.present? && @membership.status == "active" && @membership.user&.status == "active"
      end

      def permitted?(rule)
        policy = QuotePolicy.new(@membership, @quote)
        rule[:reviewer_action] ? policy.review? : true
      end

      def authorized?
        QuotePolicy.new(@membership, @quote).public_send(:"#{@action}?")
      end

      def ensure_current_version!(revision)
        expected = @expected_version || {}
        current = revision.present? &&
                  expected[:revision_id].to_s == revision.id.to_s &&
                  expected[:lock_version].to_s == @quote.lock_version.to_s &&
                  revision.revision_status == "pending_review"
        raise StaleVersion, STALE_MESSAGE unless current
      end

      def ensure_independent_reviewer!(revision)
        raise InvalidTransition, UNATTRIBUTED_MESSAGE unless revision.attribution_recorded?
        raise SeparationRequired if revision.prepared_or_edited_by?(@membership)
      end

      def record_refused_approval
        AuditEvent.record!(
          event_type: "quote.approval_refused",
          organization: @quote.organization,
          actor_membership: @membership,
          subject: @quote,
          metadata: {
            reference_number: @quote.reference_number,
            revision_id: @quote.current_revision_id,
            reason: "same_person_prepared_or_edited"
          }
        )
      end

      def revision_attributes(rule, revision)
        attrs = { revision_status: rule[:revision] }
        if @action == "submit_for_review"
          revision.record_contributor(@membership)
          attrs[:submitted_by_membership_id] = @membership.id
          attrs[:prepared_by_membership_id] = revision.prepared_by_membership_id
          attrs[:contributor_membership_ids] = revision.contributor_membership_ids
        end
        if rule[:freeze]
          now = Time.current
          attrs[:frozen_at] = now
          attrs[:recipient_snapshot] = recipient_snapshot(revision)
          attrs[:approved_by_membership] = @membership
          attrs[:approved_at] = now
        end
        if @action == "issue"
          attrs[:issued_by_membership] = @membership
          attrs[:issued_at] = Time.current
        end
        attrs
      end

      def recipient_snapshot(revision)
        {
          company_name: @quote.client_label,
          client_organization_id: @quote.client_organization_id,
          contact_name: @quote.prospective_value("contact_name").presence,
          email: @quote.prospective_value("email").presence,
          phone: @quote.prospective_value("phone").presence,
          address: @quote.prospective_value("address").presence,
          service_title: @quote.service&.title,
          title: revision.title,
          currency: revision.currency
        }.compact
      end
  end
end

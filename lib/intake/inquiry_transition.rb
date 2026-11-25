# frozen_string_literal: true

module Intake
  # The only way an enquiry's status changes after it is received. Each action lists the
  # statuses it may start from, the information it needs and its business guards. Every
  # action needs inquiries.qualify and the version of the enquiry the person was looking at.
  class InquiryTransition
    class InvalidTransition < StandardError; end
    class NotAuthorized < InvalidTransition; end
    class StaleVersion < InvalidTransition; end

    OPEN = ServiceInquiry::OPEN_STATUSES
    REASON_LIMIT = 500

    RULES = {
      "start_review" => { from: %w[submitted], to: "under_review" },
      "qualify" => { from: %w[submitted under_review needs_clarification], to: "qualified" },
      "mark_outside_scope" => { from: OPEN, to: "unqualified", ends: true },
      "mark_duplicate" => { from: OPEN, to: "merged", ends: true },
      "close" => { from: OPEN, to: "closed", ends: true },
      "reopen" => { from: ServiceInquiry::CLOSED_STATUSES, to: "under_review" },
      # Driven by clarification requests, never chosen directly by staff.
      "await_information" => { from: %w[submitted under_review qualified], to: "needs_clarification", internal: true },
      "information_received" => { from: %w[needs_clarification], to: "under_review", internal: true }
    }.freeze

    STAFF_ACTIONS = RULES.reject { |_, rule| rule[:internal] }.keys.freeze

    WRONG_STATE = {
      "start_review" => "The review of this enquiry has already started.",
      "qualify" => "Only new or open enquiries that are not already ready to quote can be marked ready to quote.",
      "reopen" => "Only closed enquiries can be reopened."
    }.freeze

    def self.apply!(inquiry:, action:, membership:, expected_lock_version:, attributes: {})
      new(inquiry:, action:, membership:, expected_lock_version:, attributes:).apply!
    end

    # Actions this person may take now; used to show only legitimate next steps.
    def self.available_actions(inquiry, membership)
      return [] unless ServiceInquiryPolicy.new(membership, inquiry).triage?

      STAFF_ACTIONS.select { |action| RULES[action][:from].include?(inquiry.current_status) }
    end

    def initialize(inquiry:, action:, membership:, expected_lock_version:, attributes: {})
      @inquiry = inquiry
      @action = action.to_s
      @membership = membership
      @expected_lock_version = expected_lock_version
      @attributes = attributes.to_h.symbolize_keys
    end

    def apply!
      rule = RULES[@action]
      raise InvalidTransition, "That action is not available." unless rule

      ServiceInquiry.transaction do
        @inquiry.lock!
        TriageGuard.authorize!(@inquiry, @membership, :triage?)
        TriageGuard.ensure_current!(@inquiry, @expected_lock_version)
        from = @inquiry.current_status
        unless rule[:from].include?(from)
          raise InvalidTransition, WRONG_STATE.fetch(@action, "This enquiry is now “#{@inquiry.status_label}”. Refresh the page to see the next steps.")
        end

        changes = public_send("#{@action}_changes")
        guard_open_quotation! if rule[:ends]
        @inquiry.update!(changes.merge(current_status: rule[:to]))
        auto_assign_reviewer! if @action == "start_review"
        audit!(from, rule[:to])
      end
      @inquiry
    end

    def start_review_changes
      { review_started_at: Time.current }
    end

    def qualify_changes
      note = TriageGuard.text(@attributes[:note])
      TriageGuard.limit!(note, ServiceInquiry::NOTE_LIMIT, "note")
      ensure_no_unanswered_questions!
      { qualified_at: Time.current, qualification_note: note, review_started_at: @inquiry.review_started_at || Time.current }
        .merge(client_organization_change)
    end

    def mark_outside_scope_changes
      note = TriageGuard.text(@attributes[:note])
      raise InvalidTransition, "Explain why this request is outside our service scope." if note.blank?

      TriageGuard.limit!(note, ServiceInquiry::NOTE_LIMIT, "explanation")
      closing("outside_scope", note)
    end

    def mark_duplicate_changes
      canonical = find_canonical
      @duplicate_reference = canonical.reference_number
      closing("duplicate", TriageGuard.text(@attributes[:note])).merge(duplicate_of_id: canonical.id)
    end

    def close_changes
      reason = @attributes[:closure_reason].to_s
      raise InvalidTransition, "Choose why the enquiry is being closed." unless ServiceInquiry::CLOSE_REASONS.key?(reason)

      note = TriageGuard.text(@attributes[:note])
      raise InvalidTransition, "Explain the reason for closing." if reason == "other" && note.blank?

      TriageGuard.limit!(note, ServiceInquiry::NOTE_LIMIT, "explanation")
      closing(reason, note)
    end

    def reopen_changes
      @reason = TriageGuard.text(@attributes[:reason])
      raise InvalidTransition, "Explain why the enquiry is being reopened." if @reason.blank?

      TriageGuard.limit!(@reason, REASON_LIMIT, "reason")
      @previous_closure = { closure_reason: @inquiry.closure_reason, closure_note: @inquiry.closure_note,
                            duplicate_of_reference: @inquiry.duplicate_of&.reference_number }
      { closure_reason: nil, closure_note: nil, closed_at: nil, duplicate_of_id: nil,
        review_started_at: @inquiry.review_started_at || Time.current }
    end

    def await_information_changes
      { review_started_at: @inquiry.review_started_at || Time.current }
    end

    def information_received_changes
      {}
    end

    private

      def closing(reason, note)
        { closure_reason: reason, closure_note: note, closed_at: Time.current }
      end

      def client_organization_change
        id = @attributes[:client_organization_id]
        return {} if id.blank?

        organization = Quote.assignable_client_organizations(@inquiry.organization).find_by(id: id.to_s)
        raise InvalidTransition, "Choose an active client organisation from the list, or leave it empty." unless organization

        { client_organization_id: organization.id }
      end

      def ensure_no_unanswered_questions!
        return unless @inquiry.respond_to?(:clarifications) && @inquiry.clarifications.awaiting_answer.exists?

        raise InvalidTransition, "Record the client’s answer, or withdraw the open question, before marking this enquiry ready to quote."
      end

      def find_canonical
        reference = @attributes[:duplicate_reference].to_s.strip.upcase
        raise InvalidTransition, "Enter the reference of the enquiry this one duplicates." if reference.blank?

        canonical = ServiceInquiryPolicy::Scope.new(@membership, ServiceInquiry.all).resolve
                                                .find_by(reference_number: reference, organization_id: @inquiry.organization_id)
        raise InvalidTransition, "No enquiry with reference #{reference} was found." unless canonical
        raise InvalidTransition, "An enquiry cannot be a duplicate of itself." if canonical.id == @inquiry.id
        if canonical.current_status == "merged"
          raise InvalidTransition, "#{reference} is itself a duplicate. Link to the original enquiry instead."
        end

        canonical
      end

      def guard_open_quotation!
        quote = @inquiry.open_quote
        return unless quote

        raise InvalidTransition,
              "Quotation #{quote.reference_number} is still open for this enquiry. Withdraw it from the quotation page first " \
              "if the offer should no longer stand."
      end

      def auto_assign_reviewer!
        return if @inquiry.assigned_membership_id.present?
        return unless InquiryAssignment.eligible?(@membership, @inquiry.organization)

        InquiryAssignment.record!(inquiry: @inquiry, actor: @membership, assignee: @membership, reason: "Started the review")
      end

      def audit!(from, to)
        AuditEvent.record!(
          event_type: "service_inquiry.#{@action}",
          organization: @inquiry.organization,
          actor_membership: @membership,
          subject: @inquiry,
          metadata: {
            reference_number: @inquiry.reference_number,
            from_status: from,
            to_status: to,
            closure_reason: @inquiry.closure_reason,
            note: (@inquiry.closure_note if RULES[@action][:ends]),
            duplicate_of_reference: @duplicate_reference,
            client_organization_id: (@inquiry.client_organization_id if @action == "qualify"),
            reason: @reason,
            previous_closure: @previous_closure&.compact.presence
          }.compact
        )
      end
  end
end

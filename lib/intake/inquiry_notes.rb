# frozen_string_literal: true

module Intake
  # Internal notes are append-only. A correction is saved as a new note linked to the
  # original, so the original wording and its author stay visible in the history.
  class InquiryNotes
    def self.add!(inquiry:, membership:, body:)
      new(inquiry:, membership:).add!(body)
    end

    def self.correct!(note:, membership:, body:)
      new(inquiry: note.service_inquiry, membership:).correct!(note, body)
    end

    def initialize(inquiry:, membership:)
      @inquiry = inquiry
      @membership = membership
    end

    def add!(body)
      ServiceInquiry.transaction do
        @inquiry.lock!
        TriageGuard.authorize!(@inquiry, @membership, :note?)
        note = @inquiry.notes.create!(author_membership: @membership, body: body)
        audit!("service_inquiry.note_added", note)
        note
      end
    end

    def correct!(original, body)
      ServiceInquiry.transaction do
        @inquiry.lock!
        TriageGuard.authorize!(@inquiry, @membership, :note?)
        unless original.author_membership_id == @membership.id || ServiceInquiryPolicy.new(@membership, @inquiry).triage?
          raise InquiryTransition::NotAuthorized, "Only the author or a team member who reviews enquiries can correct this note."
        end
        raise InquiryTransition::InvalidTransition, "This note has already been corrected." if original.corrected?

        note = @inquiry.notes.create!(author_membership: @membership, body: body, corrects_note: original)
        audit!("service_inquiry.note_corrected", note, corrects_note_id: original.id)
        note
      end
    rescue ActiveRecord::RecordNotUnique
      raise InquiryTransition::InvalidTransition, "This note has already been corrected."
    end

    private

      def audit!(event_type, note, extra = {})
        AuditEvent.record!(
          event_type: event_type,
          organization: @inquiry.organization,
          actor_membership: @membership,
          subject: @inquiry,
          metadata: { reference_number: @inquiry.reference_number, note_id: note.id }.merge(extra)
        )
      end
  end
end

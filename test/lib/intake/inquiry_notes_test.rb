# frozen_string_literal: true

require "test_helper"

class Intake::InquiryNotesTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  setup { @inquiry = submit_enquiry! }

  test "notes record author and time and cannot be edited or deleted" do
    note = Intake::InquiryNotes.add!(inquiry: @inquiry, membership: memberships(:dual_staff), body: "  Called the port agent.  ")
    assert_equal "Called the port agent.", note.body
    assert_equal memberships(:dual_staff), note.author_membership
    assert note.created_at
    assert_raises(ActiveRecord::ReadOnlyRecord) { note.update!(body: "Changed") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { note.destroy! }

    event = AuditEvent.find_by!(event_type: "service_inquiry.note_added", subject_id: @inquiry.id)
    assert_equal({ "reference_number" => @inquiry.reference_number, "note_id" => note.id }, event.metadata)
    refute_includes event.metadata.to_json, "port agent"
  end

  test "a correction keeps the original note" do
    original = Intake::InquiryNotes.add!(inquiry: @inquiry, membership: memberships(:dual_staff), body: "Vessel is in Tema.")
    correction = Intake::InquiryNotes.correct!(note: original, membership: memberships(:dual_staff), body: "Vessel is in Takoradi.")

    assert_equal original, correction.corrects_note
    assert original.reload.corrected?
    assert_equal "Vessel is in Tema.", original.body
    assert_equal 2, @inquiry.notes.count

    assert_raises(Intake::InquiryTransition::InvalidTransition) do
      Intake::InquiryNotes.correct!(note: original, membership: memberships(:dual_staff), body: "Third try")
    end
  end

  test "blank and overlong notes are refused" do
    assert_raises(ActiveRecord::RecordInvalid) { Intake::InquiryNotes.add!(inquiry: @inquiry, membership: memberships(:dual_staff), body: "   ") }
    assert_raises(ActiveRecord::RecordInvalid) do
      Intake::InquiryNotes.add!(inquiry: @inquiry, membership: memberships(:dual_staff), body: "x" * 4001)
    end
  end

  test "people who cannot work on the enquiry cannot add or correct notes" do
    surveyor = create_staff_member!
    [ surveyor, memberships(:staff_membership), memberships(:client_owner_membership) ].each do |membership|
      assert_raises(Intake::InquiryTransition::NotAuthorized) do
        Intake::InquiryNotes.add!(inquiry: @inquiry, membership: membership, body: "Should not save")
      end
    end
    assert_equal 0, @inquiry.notes.count

    assign_enquiry!(@inquiry, surveyor)
    note = Intake::InquiryNotes.add!(inquiry: @inquiry.reload, membership: surveyor, body: "Visited the site.")
    assert_equal surveyor, note.author_membership

    other_author = Intake::InquiryNotes.add!(inquiry: @inquiry, membership: memberships(:dual_staff), body: "Coordinator note")
    assert_raises(Intake::InquiryTransition::NotAuthorized) do
      Intake::InquiryNotes.correct!(note: other_author, membership: surveyor, body: "Changing someone else's note")
    end
  end
end

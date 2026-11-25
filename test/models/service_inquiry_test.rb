# frozen_string_literal: true

require "test_helper"

class ServiceInquiryTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  test "references are sequential per year" do
    first = submit_enquiry!
    second = submit_enquiry!
    assert_match(/\AANT-ENQ-#{Time.current.year}-\d{5}\z/, first.reference_number)
    assert_equal first.reference_number.split("-").last.to_i + 1, second.reference_number.split("-").last.to_i
  end

  test "reference allocation outside a transaction is refused" do
    connection = ServiceInquiry.connection
    connection.define_singleton_method(:transaction_open?) { false }
    assert_raises(ArgumentError) { Intake::InquiryReference.generate! }
  ensure
    connection.singleton_class.send(:remove_method, :transaction_open?)
  end

  test "text is normalised and email lower-cased" do
    inquiry = submit_enquiry!(company_name: "  Harbour   Logistics  ", contact_email: " AMA@Harbour.Example ")
    assert_equal "Harbour Logistics", inquiry.company_name
    assert_equal "ama@harbour.example", inquiry.contact_email
  end

  test "past preferred dates are rejected" do
    result = Intake::InquirySubmission.submit!(attributes: enquiry_attributes(preferred_date: (Date.current - 1).iso8601),
                                               service_choice: "not_sure", submission_token: SecureRandom.hex)
    refute result.saved?
    assert result.inquiry.errors[:preferred_date].any?
    assert_equal 2, result.inquiry.first_error_step
  end

  test "database rejects unknown statuses" do
    inquiry = submit_enquiry!
    assert_raises(ActiveRecord::StatementInvalid) { inquiry.update_columns(current_status: "booked") }
  end

  test "database rejects oversized descriptions" do
    inquiry = submit_enquiry!
    assert_raises(ActiveRecord::StatementInvalid) { inquiry.update_columns(description: "x" * 4001) }
  end
end

# frozen_string_literal: true

require "test_helper"

class Intake::ConcurrencyTest < ActiveSupport::TestCase
  include EnquiryTestHelper

  self.use_transactional_tests = false

  teardown do
    @inquiry_ids = Array(@inquiry_ids).compact
    next if @inquiry_ids.empty?

    quote_ids = Quote.where(service_inquiry_id: @inquiry_ids).pluck(:id)
    AuditEvent.where(subject_type: "Quote", subject_id: quote_ids).delete_all
    Quote.where(id: quote_ids).update_all(current_revision_id: nil)
    QuoteRevision.where(quote_id: quote_ids).delete_all
    Quote.where(id: quote_ids).delete_all
    StaffNotification.where(subject_type: "ServiceInquiry", subject_id: @inquiry_ids).delete_all
    AuditEvent.where(subject_type: "ServiceInquiry", subject_id: @inquiry_ids).delete_all
    ServiceInquiryAssignment.where(service_inquiry_id: @inquiry_ids).delete_all
    ServiceInquiry.where(id: @inquiry_ids).delete_all
  end

  test "concurrent enquiries receive distinct references and a shared token saves once" do
    token = SecureRandom.urlsafe_base64(24)
    results = run_concurrently(4) do |index|
      Intake::InquirySubmission.submit!(
        attributes: enquiry_attributes(company_name: "Concurrent #{index}"),
        service_choice: "not_sure",
        submission_token: index.even? ? token : SecureRandom.urlsafe_base64(24)
      )
    end
    @inquiry_ids = results.map { |r| r.inquiry.id }.uniq

    assert results.all?(&:saved?)
    assert_equal 3, @inquiry_ids.size
    references = ServiceInquiry.where(id: @inquiry_ids).pluck(:reference_number)
    assert_equal references.uniq.size, references.size
    assert_equal 1, ServiceInquiry.where(submission_token: token).count
  end

  test "concurrent prepare quotation requests produce exactly one quotation" do
    inquiry = Intake::InquirySubmission.submit!(attributes: enquiry_attributes, service_choice: "not_sure",
                                                submission_token: SecureRandom.urlsafe_base64(24)).inquiry
    @inquiry_ids = [ inquiry.id ]
    membership = memberships(:dual_staff)

    results = run_concurrently(3) do
      Commercial::QuoteFromInquiry.call(inquiry: ServiceInquiry.find(inquiry.id), membership: membership)
    end

    assert_equal 1, results.count(&:created)
    assert_equal 1, results.map { |r| r.quote.id }.uniq.size
    assert_equal 1, Quote.where(service_inquiry_id: inquiry.id).count
  end

  test "two people acting on the same version of an enquiry: one succeeds, the other is told to refresh" do
    inquiry = Intake::InquirySubmission.submit!(attributes: enquiry_attributes, service_choice: "not_sure",
                                                submission_token: SecureRandom.urlsafe_base64(24)).inquiry
    @inquiry_ids = [ inquiry.id ]
    version = inquiry.lock_version
    targets = [ memberships(:ops_manager_membership), memberships(:staff_membership) ]

    outcomes = run_concurrently(2) do |index|
      Intake::InquiryAssignment.assign!(inquiry: ServiceInquiry.find(inquiry.id), membership: memberships(:dual_staff),
                                        assignee_id: targets[index].id, reason: nil, expected_lock_version: version)
      :assigned
    rescue Intake::InquiryTransition::StaleVersion
      :stale
    end

    assert_equal %i[assigned stale], outcomes.sort
    assert_equal 1, ServiceInquiryAssignment.where(service_inquiry_id: inquiry.id).count

    results = run_concurrently(2) do |index|
      Intake::InquiryTransition.apply!(inquiry: ServiceInquiry.find(inquiry.id), action: index.zero? ? :start_review : :close,
                                       membership: memberships(:dual_staff), expected_lock_version: version + 1,
                                       attributes: { closure_reason: "cancelled" })
      :changed
    rescue Intake::InquiryTransition::StaleVersion
      :stale
    end
    assert_equal %i[changed stale], results.sort
  end

  private

    def run_concurrently(count)
      gate = Concurrent::CountDownLatch.new(1)
      threads = count.times.map do |index|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            gate.wait
            yield index
          end
        end
      end
      gate.count_down
      threads.map(&:value)
    end
end

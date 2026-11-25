# frozen_string_literal: true

require "test_helper"

class ServiceInquiryPolicyTest < ActiveSupport::TestCase
  include EnquiryTestHelper
  include QuoteTestHelper

  setup { @inquiry = submit_enquiry! }

  test "coordinators and operations managers can view and prepare quotations" do
    %i[dual_staff ops_manager_membership].each do |key|
      policy = ServiceInquiryPolicy.new(memberships(key), @inquiry)
      assert policy.show?, "#{key} should view"
      assert policy.prepare_quotation?, "#{key} should prepare"
    end
  end

  test "general staff and client members are denied" do
    %i[staff_membership client_owner_membership client_membership].each do |key|
      membership = memberships(key)
      refute ServiceInquiryPolicy.new(membership, @inquiry).show?, "#{key} should not view"
      assert_empty ServiceInquiryPolicy::Scope.new(membership, ServiceInquiry.all).resolve, "#{key} scope should be empty"
    end
  end

  test "scope is limited to the staff member's organisation" do
    scope = ServiceInquiryPolicy::Scope.new(memberships(:dual_staff), ServiceInquiry.all).resolve
    assert_includes scope, @inquiry
    assert scope.all? { |inquiry| inquiry.organization_id == memberships(:dual_staff).organization_id }
  end

  test "suspended or denied memberships lose access" do
    membership = memberships(:dual_staff)
    deny_permission!(membership, "inquiries.view_all")
    refute ServiceInquiryPolicy.new(membership.reload, @inquiry).show?
  end
end

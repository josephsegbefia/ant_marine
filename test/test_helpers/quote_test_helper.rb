# frozen_string_literal: true

module QuoteTestHelper
  def create_draft_quote(membership: memberships(:dual_staff))
    Commercial::QuoteBuilder.create!(organization: organizations(:ant_marine), membership: membership)
  end

  def create_ready_quote(membership: memberships(:dual_staff), lines: [ [ "Underwater hull inspection", "2", "1250.00" ] ])
    quote = create_draft_quote(membership: membership)
    quote.update!(prospective_client: {
      "company_name" => "Harbour Logistics Ltd",
      "contact_name" => "Ama Mensah",
      "email" => "ama@example.com",
      "phone" => "+233 20 000 0000"
    })
    revision = quote.current_revision
    revision.assign_attributes(
      title: "Hull inspection for MV Example",
      scope_description: "Underwater inspection of hull plating and appendages.",
      deliverables: "Inspection report with photographs.",
      exclusions: "Repairs and dry-docking.",
      currency: "GHS",
      valid_until: Date.current + 30,
      payment_terms: "Payable within 30 days of invoice."
    )
    lines.each_with_index do |(description, quantity, price), index|
      revision.line_items.build(description: description, quantity: quantity, unit: "each", unit_price: price, position: index)
    end
    revision.save!
    quote.reload
  end

  def approve_quote!(quote, preparer: memberships(:dual_staff), reviewer: memberships(:ops_manager_membership))
    Commercial::QuoteTransition.apply!(quote: quote, action: :submit_for_review, membership: preparer)
    review_quote!(quote, :approve, reviewer: reviewer)
    quote.reload
  end

  def review_quote!(quote, action, reviewer: memberships(:ops_manager_membership), reason: nil, expected_version: nil)
    Commercial::QuoteTransition.apply!(
      quote: quote,
      action: action,
      membership: reviewer,
      reason: reason,
      expected_version: expected_version || expected_version_for(quote)
    )
  end

  # What a reviewer's browser would hold after opening the quotation now.
  def expected_version_for(quote)
    fresh = Quote.find(quote.id)
    { revision_id: fresh.current_revision_id, lock_version: fresh.lock_version }
  end

  def reviewer_form_params(quote)
    version = expected_version_for(quote)
    { expected_revision_id: version[:revision_id], expected_lock_version: version[:lock_version] }
  end

  def deny_permission!(membership, key, granted_by: memberships(:super_admin_membership))
    PermissionOverride.create!(
      membership: membership,
      permission: Permission.find_by!(key: key),
      effect: "deny",
      granted_by_membership: granted_by,
      reason: "Test restriction"
    )
  end
end

ActiveSupport::TestCase.include(QuoteTestHelper)

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

  def create_revision!(quote, membership: memberships(:dual_staff), reason: "Client asked for a revised scope.")
    Commercial::QuoteRevisionCreator.create!(quote: quote, membership: membership, reason: reason,
                                             expected_version: expected_version_for(quote))
  end

  # Simulates a version the mail provider accepted; real issuance runs through QuoteDispatcher.
  def mark_issued!(quote)
    quote.reload.current_revision.update!(revision_status: "issued", issued_at: Time.current)
    quote.update_columns(status: "issued")
    quote.reload
  end

  def extract_pdf_text(data)
    data.b.scan(/\[(.*?)\]\s*TJ|<([0-9a-fA-F]+)>\s*Tj/m).map do |array, single|
      chunks = array ? array.scan(/<([0-9a-fA-F]+)>/).flatten : [ single ]
      chunks.map { |hex| [ hex ].pack("H*").force_encoding("Windows-1252").encode("UTF-8") }.join
    end.join("\n")
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

  # Test-admin only: table-owner DISABLE TRIGGER for non-transactional cleanup.
  # Application runtime must never call this. Prefer travel_to / pre-freeze setup over mutating frozen rows.
  def with_history_protection_admin
    raise "History admin helper is test-only" unless Rails.env.test?

    connection = ActiveRecord::Base.connection
    connection.execute("ALTER TABLE quote_revisions DISABLE TRIGGER quote_revisions_history_protect")
    connection.execute("ALTER TABLE quote_line_items DISABLE TRIGGER quote_line_items_history_protect")
    connection.execute("ALTER TABLE quote_responses DISABLE TRIGGER quote_responses_history_protect")
    yield
  ensure
    connection.execute("ALTER TABLE quote_revisions ENABLE TRIGGER quote_revisions_history_protect")
    connection.execute("ALTER TABLE quote_line_items ENABLE TRIGGER quote_line_items_history_protect")
    connection.execute("ALTER TABLE quote_responses ENABLE TRIGGER quote_responses_history_protect")
  end
end

ActiveSupport::TestCase.include(QuoteTestHelper)

# frozen_string_literal: true

module Intake
  # Suggests enquiries that may be the same request: same contact email or same company
  # name, within the viewer's own access scope and organisation. Suggestions only — staff
  # decide whether to mark a duplicate, and nothing is merged or moved.
  module DuplicateFinder
    WINDOW = 180.days
    LIMIT = 5

    module_function

    def candidates(inquiry, membership)
      ServiceInquiryPolicy::Scope.new(membership, ServiceInquiry.all).resolve
                                 .where(organization_id: inquiry.organization_id)
                                 .where.not(id: inquiry.id)
                                 .where(submitted_at: (inquiry.submitted_at - WINDOW)..(inquiry.submitted_at + WINDOW))
                                 .where("lower(contact_email) = :email OR lower(company_name) = :company",
                                        email: inquiry.contact_email.to_s.downcase, company: inquiry.company_name.to_s.downcase)
                                 .recent_first.limit(LIMIT)
    end
  end
end

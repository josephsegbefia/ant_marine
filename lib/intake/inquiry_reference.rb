# frozen_string_literal: true

module Intake
  # Allocates enquiry references (ANT-ENQ-2026-00001), serialized per year with a
  # transaction-scoped advisory lock. The unique index is the final guard.
  class InquiryReference
    LOCK_NAMESPACE = "ant_marine.inquiry_reference"

    def self.generate!(year: Time.current.year)
      connection = ServiceInquiry.connection
      raise ArgumentError, "Enquiry references must be allocated inside a transaction." unless connection.transaction_open?

      connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{connection.quote("#{LOCK_NAMESPACE}:#{year}")}))")

      prefix = format("ANT-ENQ-%d-", year)
      numbers = ServiceInquiry.where("reference_number LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%")
                              .pluck(:reference_number)
                              .filter_map { |ref| ref.delete_prefix(prefix)[/\A\d+\z/]&.to_i }
      format("%s%05d", prefix, (numbers.max || 0) + 1)
    end
  end
end

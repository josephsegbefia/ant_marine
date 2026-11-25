# frozen_string_literal: true

module Commercial
  # Allocates human-readable references (ANT-Q-2026-00001). Allocation is serialized
  # per organization and year with a transaction-scoped Postgres advisory lock, so
  # concurrent drafts never compute the same next number. The unique index on
  # (organization_id, reference_number) remains the final guard.
  class QuoteReference
    class Collision < StandardError; end

    LOCK_NAMESPACE = "ant_marine.quote_reference"

    def self.generate!(organization:, year: Time.current.year)
      connection = Quote.connection
      raise Collision, "Quotation references must be allocated inside a transaction." unless connection.transaction_open?

      lock_key = connection.quote("#{LOCK_NAMESPACE}:#{organization.id}:#{year}")
      connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{lock_key}))")

      prefix = format("ANT-Q-%d-", year)
      numbers = Quote.where(organization: organization)
                     .where("reference_number LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%")
                     .pluck(:reference_number)
                     .filter_map { |ref| ref.delete_prefix(prefix)[/\A\d+\z/]&.to_i }
      format("%s%05d", prefix, (numbers.max || 0) + 1)
    end
  end
end

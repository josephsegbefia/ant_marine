# frozen_string_literal: true

module Delivery
  # Allocates ANT-PRJ-YYYY-##### under a transaction-scoped advisory lock.
  class Reference
    class Collision < StandardError; end

    LOCK_NAMESPACE = "ant_marine.project_reference"

    def self.generate!(year: Time.current.year)
      connection = Project.connection
      raise Collision, "Project references must be allocated inside a transaction." unless connection.transaction_open?

      lock_key = connection.quote("#{LOCK_NAMESPACE}:#{year}")
      connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{lock_key}))")

      prefix = format("ANT-PRJ-%d-", year)
      numbers = Project.where("reference_number LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%")
                       .pluck(:reference_number)
                       .filter_map { |ref| ref.delete_prefix(prefix)[/\A\d+\z/]&.to_i }
      format("%s%05d", prefix, (numbers.max || 0) + 1)
    end
  end
end

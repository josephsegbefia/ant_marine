# frozen_string_literal: true

module Reports
  class Reference
    class Collision < StandardError; end

    LOCK_NAMESPACE = "ant_marine.report_reference"

    def self.generate!(year: Time.current.year)
      connection = Report.connection
      raise Collision, "Report references must be allocated inside a transaction." unless connection.transaction_open?

      lock_key = connection.quote("#{LOCK_NAMESPACE}:#{year}")
      connection.execute("SELECT pg_advisory_xact_lock(hashtext(#{lock_key}))")

      prefix = format("ANT-RPT-%d-", year)
      numbers = Report.where("reference_number LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(prefix)}%")
                      .pluck(:reference_number)
                      .filter_map { |ref| ref.delete_prefix(prefix)[/\A\d+\z/]&.to_i }
      format("%s%05d", prefix, (numbers.max || 0) + 1)
    end
  end
end

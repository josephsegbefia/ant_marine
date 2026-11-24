# frozen_string_literal: true

module Commercial
  class QuoteReference
    class Collision < StandardError; end

    def self.generate!(organization:)
      year = Time.current.year
      5.times do
        prefix = format("ANT-Q-%d-", year)
        last = Quote.where(organization: organization).where("reference_number LIKE ?", "#{prefix}%")
                    .order(:reference_number).last&.reference_number
        seq = last ? last.split("-").last.to_i + 1 : 1
        ref = format("%s%05d", prefix, seq)
        return ref unless Quote.exists?(organization: organization, reference_number: ref)
      end

      raise Collision, "Could not allocate a unique quotation reference."
    end
  end
end

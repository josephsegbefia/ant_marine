# frozen_string_literal: true

module Inspections
  class RequestCorrections
    Result = Data.define(:inspection)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, inspection:, comments:)
      new(membership: membership).call(inspection: inspection, comments: comments)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(inspection:, comments:)
      raise Denied, "You are not allowed to request corrections on this inspection." unless Inspections::Access.can_coordinate?(@membership, inspection)
      raise InvalidState, "Explain what needs to be corrected." if comments.to_s.strip.blank?
      raise InvalidState, "Only a submitted inspection can be sent back for correction." unless inspection.status == "submitted"

      locked = nil
      Inspection.transaction do
        locked = Inspection.lock.find(inspection.id)
        raise InvalidState, "Only a submitted inspection can be sent back for correction." unless locked.status == "submitted"

        locked.update!(status: "corrections_requested")
        Inspections::Audit.corrections_requested(
          inspection: locked,
          actor_membership: @membership,
          comments: comments
        )
      end

      Result.new(inspection: locked)
    end
  end
end

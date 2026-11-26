# frozen_string_literal: true

module Inspections
  class Complete
    Result = Data.define(:inspection)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, inspection:)
      new(membership: membership).call(inspection: inspection)
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(inspection:)
      raise Denied, "You are not allowed to complete this inspection." unless Inspections::Access.can_coordinate?(@membership, inspection)
      raise InvalidState, "Only a submitted inspection can be marked complete." unless inspection.status == "submitted"

      locked = nil
      Inspection.transaction do
        locked = Inspection.lock.find(inspection.id)
        raise InvalidState, "Only a submitted inspection can be marked complete." unless locked.status == "submitted"

        locked.update!(status: "completed", completed_at: Time.current)
        Inspections::Audit.completed(inspection: locked, actor_membership: @membership)
        Delivery::TechnicalProgress.sync!(project: locked.project)
      end

      Result.new(inspection: locked)
    end
  end
end

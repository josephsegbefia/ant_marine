# frozen_string_literal: true

module Storage
  class ProofPolicy < ApplicationPolicy
    def create?
      allowed?("documents.upload")
    end
  end
end

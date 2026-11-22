# frozen_string_literal: true

module Storage
  class AssetPolicy < ApplicationPolicy
    def show?
      return false unless record.is_a?(Storage::Asset)
      return false unless record.downloadable?
      return false unless membership.organization_id == record.organization_id
      return false unless allowed?("documents.download")
      return false if record.confidential? && !allowed?("documents.access_confidential")

      true
    end
  end
end

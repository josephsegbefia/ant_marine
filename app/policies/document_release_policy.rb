# frozen_string_literal: true

class DocumentReleasePolicy < ApplicationPolicy
  def show?
    Documents::Access.can_view_metadata?(membership, record.document)
  end

  def create?
    Documents::Access.can_release?(membership, record.is_a?(Document) ? record : record.document)
  end

  def revoke?
    Documents::Access.can_revoke_release?(membership, record)
  end
end

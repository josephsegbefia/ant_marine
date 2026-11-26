# frozen_string_literal: true

class DocumentVersionPolicy < ApplicationPolicy
  def show?
    Documents::Access.can_view_metadata?(membership, record.document)
  end

  def download?
    Documents::Access.can_download_version?(membership, record)
  end

  def create?
    Documents::Access.can_upload?(membership, record.document.project)
  end

  def review?
    Documents::Access.can_review?(membership, record.document)
  end

  def release?
    Documents::Access.can_release?(membership, record.document)
  end
end

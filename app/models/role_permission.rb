# frozen_string_literal: true

class RolePermission < ApplicationRecord
  belongs_to :permission

  validates :role_key, inclusion: { in: RoleKeys::ALL }
  validates :permission_id, uniqueness: { scope: :role_key }
end

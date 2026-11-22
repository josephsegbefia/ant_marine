# frozen_string_literal: true

module RoleKeys
  STAFF = %w[
    staff.super_administrator
    staff.operations_manager
    staff.project_coordinator
    staff.surveyor
    staff.technical_reviewer
    staff.finance_officer
    staff.content_manager
    staff.general_staff
  ].freeze

  CLIENT = %w[
    client.org_owner
    client.org_administrator
    client.client_manager
    client.client_member
    client.client_finance
  ].freeze

  ALL = (STAFF + CLIENT).freeze

  def self.staff?(role_key)
    STAFF.include?(role_key)
  end

  def self.client?(role_key)
    CLIENT.include?(role_key)
  end
end

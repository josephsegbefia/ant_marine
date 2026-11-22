# frozen_string_literal: true

module RoleLabels
  STAFF = {
    "staff.super_administrator" => "Super Administrator",
    "staff.operations_manager" => "Operations Manager",
    "staff.project_coordinator" => "Project Coordinator",
    "staff.surveyor" => "Surveyor / Consultant",
    "staff.technical_reviewer" => "Technical Reviewer",
    "staff.finance_officer" => "Finance Officer",
    "staff.content_manager" => "Content Manager",
    "staff.general_staff" => "General Staff"
  }.freeze

  CLIENT = {
    "client.org_owner" => "Organisation Owner",
    "client.org_administrator" => "Organisation Administrator",
    "client.client_manager" => "Client Manager",
    "client.client_member" => "Client Member",
    "client.client_finance" => "Client Finance Contact"
  }.freeze

  ALL = STAFF.merge(CLIENT).freeze

  INVITATION_STATUS = {
    "pending" => "Pending",
    "accepted" => "Accepted",
    "revoked" => "Revoked",
    "expired" => "Expired"
  }.freeze

  def self.label(role_key)
    ALL.fetch(role_key) do
      raise KeyError, "Unknown role key: #{role_key}" if RoleKeys::ALL.include?(role_key)

      role_key
    end
  end

  def self.invitation_status(status)
    INVITATION_STATUS.fetch(status, status.to_s.capitalize)
  end

  def self.options_for_roles(role_keys)
    role_keys.map { |key| [ label(key), key ] }
  end
end

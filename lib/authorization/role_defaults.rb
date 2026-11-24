# frozen_string_literal: true

module Authorization
  # Default permission keys per canonical role — sourced from DEFAULT_ROLE_MATRIX.md
  module RoleDefaults
    OPS_MANAGER = %w[
      inquiries.view_all inquiries.qualify quotes.view_all quotes.create quotes.approve quotes.send quotes.withdraw
      bookings.view_all bookings.confirm projects.view_all projects.create projects.manage projects.assign
      vessels.view_all vessels.manage inspections.view documents.manage documents.request_upload
      documents.download documents.preview reports.review reports.release reports.view_draft_staff
      billing.view billing.manage messages.view messages.send analytics.view_business analytics.export
      team.view team.invite team.suspend audit.view_staff company.settings_manage_staff
      notifications.manage_preferences
    ].freeze

    PROJECT_COORDINATOR = %w[
      inquiries.view_all inquiries.qualify quotes.view_all quotes.create quotes.approve quotes.send quotes.withdraw
      bookings.view_all bookings.confirm projects.view_all projects.create projects.manage projects.assign
      vessels.view_all vessels.manage documents.upload documents.download documents.preview documents.manage
      documents.request_upload reports.view_draft_staff reports.release billing.view messages.view
      messages.send team.view training.manage notifications.manage_preferences
    ].freeze

    SURVEYOR = %w[
      inquiries.view_assigned projects.view_assigned assignments.participate bookings.view_all
      vessels.view_all inspections.view inspections.edit documents.upload documents.download documents.preview
      reports.draft reports.view_draft_staff messages.view messages.send team.view notifications.manage_preferences
    ].freeze

    TECHNICAL_REVIEWER = %w[
      projects.view_assigned inspections.view documents.download documents.preview reports.review
      reports.approve reports.view_draft_staff messages.view team.view notifications.manage_preferences
    ].freeze

    FINANCE_OFFICER = %w[
      billing.view_all billing.view billing.manage billing.record_payment billing.adjust
      documents.download team.view notifications.manage_preferences
    ].freeze

    CONTENT_MANAGER = %w[
      content.view_draft content.manage content.publish training.manage analytics.view_business
      team.view notifications.manage_preferences
    ].freeze

    GENERAL_STAFF = %w[
      inquiries.view_assigned projects.view_assigned assignments.participate documents.download
      documents.preview messages.view team.view notifications.manage_preferences
    ].freeze

    CLIENT_OWNER = %w[
      inquiries.create inquiries.view_org quotes.view_org quotes.accept quotes.decline bookings.request
      projects.view_org vessels.view_org vessels.manage_org documents.upload documents.download
      documents.preview documents.access_confidential reports.view_org billing.view messages.view
      messages.send team.view team.invite team.manage_roles team.manage_permissions team.suspend
      team.transfer_ownership team.bulk_permission_change company.settings_view company.settings_manage
      audit.view_org audit.view_permission_changes notifications.manage_preferences
    ].freeze

    CLIENT_ORG_ADMIN = (CLIENT_OWNER - %w[
      team.manage_roles team.manage_permissions team.transfer_ownership team.bulk_permission_change
    ] + %w[team.manage_team_delegated]).freeze

    CLIENT_MANAGER = %w[
      inquiries.create inquiries.view_org quotes.view_org quotes.accept quotes.decline bookings.request
      projects.view_org vessels.view_org vessels.manage_org documents.upload documents.download
      documents.preview reports.view_org billing.view messages.view messages.send team.view team.invite
      company.settings_view notifications.manage_preferences
    ].freeze

    CLIENT_MEMBER = %w[
      inquiries.create inquiries.view_org quotes.view_org bookings.request projects.view_org vessels.view_org
      documents.upload documents.download documents.preview reports.view_org messages.view messages.send
      team.view notifications.manage_preferences
    ].freeze

    CLIENT_FINANCE = %w[
      billing.view projects.view_org documents.download team.view notifications.manage_preferences
    ].freeze

    ROLE_KEYS = {
      "staff.super_administrator" => :staff_catalogue,
      "staff.operations_manager" => OPS_MANAGER,
      "staff.project_coordinator" => PROJECT_COORDINATOR,
      "staff.surveyor" => SURVEYOR,
      "staff.technical_reviewer" => TECHNICAL_REVIEWER,
      "staff.finance_officer" => FINANCE_OFFICER,
      "staff.content_manager" => CONTENT_MANAGER,
      "staff.general_staff" => GENERAL_STAFF,
      "client.org_owner" => CLIENT_OWNER,
      "client.org_administrator" => CLIENT_ORG_ADMIN,
      "client.client_manager" => CLIENT_MANAGER,
      "client.client_member" => CLIENT_MEMBER,
      "client.client_finance" => CLIENT_FINANCE
    }.freeze

    def self.keys_for(role_key)
      entry = ROLE_KEYS.fetch(role_key) do
        raise KeyError, "Unknown role key: #{role_key}"
      end

      if entry == :staff_catalogue
        PermissionCatalogue.staff_applicable_keys
      else
        entry
      end
    end

    def self.all_role_keys
      ROLE_KEYS.keys
    end
  end
end

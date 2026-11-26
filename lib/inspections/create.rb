# frozen_string_literal: true

module Inspections
  class Create
    Result = Data.define(:inspection)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.available?
      !Rails.env.production?
    end

    def self.call(membership:, project:, title:, inspection_type:, template_version: nil,
                  assignee: nil, vessel_name: nil, location: nil)
      new(membership: membership).call(
        project: project,
        title: title,
        inspection_type: inspection_type,
        template_version: template_version,
        assignee: assignee,
        vessel_name: vessel_name,
        location: location
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(project:, title:, inspection_type:, template_version:, assignee:, vessel_name:, location:)
      raise Denied, "Simulated inspections are not available in production yet." unless self.class.available?
      raise Denied, "Simulated inspections are not available for live projects in production." if Rails.env.production? && project.simulated?
      raise Denied, "You are not allowed to create inspections for this project." unless Inspections::Access.can_list_project_inspections?(@membership, project)
      raise Denied, "You need project management permission to start an inspection." unless Authorization::EffectivePermissions.new(@membership).allowed?("projects.manage")
      raise InvalidState, "Only simulated projects can receive development inspections." unless project.simulated?
      raise InvalidState, "Enter a title for this inspection." if title.to_s.strip.blank?
      raise InvalidState, "Enter the inspection type." if inspection_type.to_s.strip.blank?

      version = resolve_template_version!(project, template_version)
      raise InvalidState, "Choose a published checklist template." unless published_template?(version)

      if assignee.present? && assignee.organization_id != project.operating_organization_id
        raise InvalidState, "The assigned surveyor must belong to your organisation."
      end

      inspection = nil
      Inspection.transaction do
        inspection = Inspection.create!(
          reference_number: Inspections::Reference.generate!,
          operating_organization: project.operating_organization,
          client_organization: project.client_organization,
          project: project,
          inspection_template_version: version,
          title: title.to_s.strip,
          inspection_type: inspection_type.to_s.strip,
          vessel_name: vessel_name.to_s.strip.presence,
          location: location.to_s.strip.presence,
          status: assignee.present? ? "assigned" : "draft",
          mode: "simulated",
          created_by_membership: @membership,
          assigned_surveyor_membership: assignee
        )
        audit = Inspections::Audit.created(inspection: inspection, actor_membership: @membership)
        if assignee.present? && assignee.id != @membership.id
          Notifications::StaffPublisher.inspection_assigned(inspection: inspection, audit_event: audit, actor: @membership)
        end
      end

      Result.new(inspection: inspection)
    end

    private

      def resolve_template_version!(project, template_version)
        return template_version if template_version.is_a?(InspectionTemplateVersion)

        template = Inspections::QaTemplateSeeder.seed!(
          operating_organization: project.operating_organization,
          created_by_membership: @membership
        )
        template.current_version
      end

      def published_template?(version)
        version.present? &&
          version.published_at.present? &&
          version.inspection_template.status == "published"
      end
  end
end

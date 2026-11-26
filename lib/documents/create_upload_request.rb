# frozen_string_literal: true

module Documents
  class CreateUploadRequest
    Result = Data.define(:upload_request)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, project:, title:, document_category:, instructions: nil, due_on: nil)
      new(membership: membership).call(
        project: project,
        title: title,
        document_category: document_category,
        instructions: instructions,
        due_on: due_on
      )
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(project:, title:, document_category:, instructions:, due_on:)
      raise Denied, "Document uploads are not available in production yet." unless Documents::Upload.available?
      raise Denied, "You are not allowed to request files for this project." unless Documents::Access.can_request_upload?(@membership, project)
      raise InvalidState, "Choose a recognised document category." unless Document::CATEGORIES.key?(document_category.to_s)
      raise InvalidState, "Enter a clear title for the requested file." if title.to_s.strip.blank?
      raise Denied, "Document requests are not available in production for simulated projects." if Rails.env.production? && project.simulated?

      request = nil
      UploadRequest.transaction do
        request = UploadRequest.create!(
          project: project,
          operating_organization: project.operating_organization,
          client_organization: project.client_organization,
          title: title.to_s.strip,
          instructions: instructions.to_s.strip.presence,
          document_category: document_category.to_s,
          due_on: due_on.presence,
          status: "requested",
          requested_by_membership: @membership
        )
        audit = Documents::Audit.upload_requested(upload_request: request, actor_membership: @membership)
        Notifications::StaffPublisher.upload_requested(upload_request: request, audit_event: audit, actor: @membership)
      end

      Result.new(upload_request: request)
    end
  end
end

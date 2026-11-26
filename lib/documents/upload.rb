# frozen_string_literal: true

module Documents
  class Upload
    Result = Data.define(:document, :version)

    class Error < StandardError; end
    class Denied < Error; end
    class InvalidState < Error; end

    def self.call(membership:, project:, filename:, io:, title:, category:, classification: "standard",
                  visibility_intent: "internal", description: nil, document: nil, upload_request: nil)
      new(membership: membership).call(
        project: project,
        filename: filename,
        io: io,
        title: title,
        category: category,
        classification: classification,
        visibility_intent: visibility_intent,
        description: description,
        document: document,
        upload_request: upload_request
      )
    end

    def self.available?
      !Rails.env.production?
    end

    def initialize(membership:)
      @membership = membership
    end

    def call(project:, filename:, io:, title:, category:, classification:, visibility_intent:,
             description:, document:, upload_request:)
      raise Denied, "Document uploads are not available in production for simulated projects." if unavailable?(project)
      raise InvalidState, "Choose a recognised document category." unless Document::CATEGORIES.key?(category.to_s)
      raise InvalidState, "Choose a valid classification." unless Document::CLASSIFICATIONS.include?(classification.to_s)
      raise InvalidState, "Choose a valid visibility setting." unless Document::VISIBILITY_INTENTS.include?(visibility_intent.to_s)

      if upload_request.present?
        submit_via_request!(project, upload_request, filename, io, title, category, classification, visibility_intent, description)
      elsif document.present?
        add_version!(project, document, filename, io)
      else
        staff_new_document!(project, filename, io, title, category, classification, visibility_intent, description)
      end
    end

    private

      attr_reader :membership

      def unavailable?(project)
        Rails.env.production? && project.simulated?
      end

      def assert_staff_upload!(project)
        raise Denied, "You are not allowed to upload files for this project." unless Documents::Access.can_upload?(membership, project)
        raise Denied, "Only staff can start a new staff document." unless membership.staff_domain?
      end

      def assert_client_submit!(project, upload_request)
        raise Denied, "You are not allowed to upload files for this project." unless Documents::Access.can_upload?(membership, project)
        raise InvalidState, "This upload request is not open." unless upload_request.open?
        raise InvalidState, "Upload request belongs to a different project." unless upload_request.project_id == project.id
      end

      def staff_new_document!(project, filename, io, title, category, classification, visibility_intent, description)
        assert_staff_upload!(project)
        organization = project.operating_organization
        asset = create_storage_asset!(organization: organization, filename: filename, io: io, classification: classification)

        document = nil
        version = nil
        Document.transaction do
          document = Document.create!(
            operating_organization: organization,
            client_organization: project.client_organization,
            project: project,
            title: title.to_s.strip,
            category: category.to_s,
            classification: classification,
            visibility_intent: visibility_intent,
            workflow_status: "working_draft",
            created_by_membership: membership,
            description: description.to_s.strip.presence
          )
          version = create_version!(document: document, asset: asset)
        end

        enqueue_scan_and_audit(document, version)
        Result.new(document: document, version: version)
      end

      def add_version!(project, document, filename, io)
        raise InvalidState, "Document belongs to a different project." unless document.project_id == project.id

        if membership.staff_domain?
          assert_staff_upload!(project)
          staff_upload = true
        elsif membership.client_domain?
          raise Denied, "You are not allowed to upload files for this project." unless Documents::Access.can_upload?(membership, project)
          raise InvalidState, "Only client-submitted documents can receive a replacement from the client." unless document.visibility_intent == "client_submitted"
          raise InvalidState, "Wait for a correction request before uploading a replacement." unless document.workflow_status == "changes_requested" || document.upload_request&.open?
          staff_upload = false
        else
          raise Denied, "You are not allowed to upload files for this project."
        end

        organization = project.operating_organization
        asset = create_storage_asset!(organization: organization, filename: filename, io: io, classification: document.classification)

        version = nil
        Document.transaction do
          locked = Document.lock.find(document.id)
          version = create_version!(document: locked, asset: asset)
          reset_workflow_after_version!(locked, staff_upload: staff_upload)
          if !staff_upload && locked.upload_request&.status == "changes_required"
            locked.upload_request.update!(status: "submitted")
          end
        end

        enqueue_scan_and_audit(document, version)
        Result.new(document: document.reload, version: version)
      end

      def submit_via_request!(project, upload_request, filename, io, title, category, classification, visibility_intent, description)
        assert_client_submit!(project, upload_request)
        category = upload_request.document_category
        store_org = project.operating_organization
        asset = create_storage_asset!(organization: store_org, filename: filename, io: io, classification: classification)

        document = nil
        version = nil
        Document.transaction do
          document = Document.create!(
            operating_organization: project.operating_organization,
            client_organization: project.client_organization,
            project: project,
            title: title.to_s.strip.presence || upload_request.title,
            category: category,
            classification: classification,
            visibility_intent: membership.client_domain? ? "client_submitted" : visibility_intent,
            workflow_status: "submitted",
            upload_request: upload_request,
            created_by_membership: membership,
            description: description.to_s.strip.presence
          )
          version = create_version!(document: document, asset: asset)
          # Upload alone does not satisfy the request — only marks it submitted.
          upload_request.update!(status: "submitted") if membership.client_domain? && upload_request.status == "requested"
        end

        enqueue_scan_and_audit(document, version)
        Result.new(document: document, version: version)
      end

      def create_storage_asset!(organization:, filename:, io:, classification:)
        validated = Storage::ContentValidator.call(filename: filename, io: io)
        storage_key = SecureRandom.uuid
        checksum_sha256 = Digest::SHA256.hexdigest(validated[:bytes])

        asset = nil
        ActiveRecord::Base.transaction do
          asset = Storage::Asset.create!(
            organization: organization,
            uploaded_by_membership: membership,
            scan_status: "pending_upload",
            classification: classification,
            filename: File.basename(filename),
            content_type: validated[:content_type],
            byte_size: validated[:byte_size],
            checksum_sha256: checksum_sha256,
            storage_key: storage_key,
            encryption_key_version: Storage::KeyMaterial.current_version
          )

          blob = ActiveStorage::Blob.create_and_upload!(
            io: StringIO.new(validated[:bytes]),
            filename: asset.filename,
            content_type: asset.content_type,
            identify: false,
            key: storage_key
          )
          asset.update!(active_storage_blob_id: blob.id)
        end
        asset
      end

      def create_version!(document:, asset:)
        version_number = (document.document_versions.maximum(:version_number) || 0) + 1
        version = document.document_versions.create!(
          version_number: version_number,
          storage_asset: asset,
          filename: asset.filename,
          content_type: asset.content_type,
          byte_size: asset.byte_size,
          checksum_sha256: asset.checksum_sha256,
          uploaded_by_membership: membership,
          created_at: Time.current
        )
        document.update!(current_version: version)
        version
      end

      def reset_workflow_after_version!(document, staff_upload:)
        if staff_upload
          document.update!(workflow_status: "working_draft")
        else
          document.update!(workflow_status: "submitted")
        end
      end

      def enqueue_scan_and_audit(document, version)
        ScanStorageAssetJob.perform_later(version.storage_asset_id)
        audit = Documents::Audit.document_uploaded(document: document, version: version, actor_membership: membership)
        Notifications::StaffPublisher.document_uploaded(document: document, audit_event: audit, actor: membership)
      end
  end
end

# frozen_string_literal: true

module PublicContent
  class Transition
    class InvalidTransition < StandardError; end

    def self.submit_for_review!(record:, membership:)
      new(record:, membership:).submit_for_review!
    end

    def self.withdraw!(record:, membership:)
      new(record:, membership:).withdraw!
    end

    def self.approve!(record:, membership:)
      new(record:, membership:).approve!
    end

    def self.publish!(record:, membership:)
      new(record:, membership:).publish!
    end

    def self.unpublish!(record:, membership:)
      new(record:, membership:).unpublish!
    end

    def self.archive!(record:, membership:)
      new(record:, membership:).archive!
    end

    def initialize(record:, membership:)
      @record = record
      @membership = membership
    end

    def submit_for_review!
      ensure_transition!(from: %w[draft], to: "in_review")
      if @record.is_a?(Service) && !@record.valid?(:editorial)
        raise InvalidTransition, @record.errors.full_messages.to_sentence
      end
      @record.update!(
        status: "in_review",
        submitted_at: Time.current,
        updated_by_membership: @membership
      )
      audit!("public_content.submitted", from: "draft", to: "in_review")
      @record
    end

    def withdraw!
      ensure_transition!(from: %w[in_review], to: "draft")
      @record.update!(
        status: "draft",
        updated_by_membership: @membership
      )
      audit!("public_content.withdrawn", from: "in_review", to: "draft")
      @record
    end

    def approve!
      ensure_transition!(from: %w[in_review], to: "approved")
      @record.update!(
        status: "approved",
        approved_at: Time.current,
        approved_by_membership: @membership,
        updated_by_membership: @membership
      )
      audit!("public_content.approved", from: "in_review", to: "approved")
      @record
    end

    def publish!
      from_status = @record.status
      ensure_transition!(from: %w[approved published], to: "published")

      Snapshot.copy_service!(@record) if @record.is_a?(Service)
      Snapshot.copy_site_page!(@record) if @record.is_a?(PublicSitePage)

      attrs = {
        status: "published",
        published_at: Time.current,
        published_by_membership: @membership,
        updated_by_membership: @membership
      }
      attrs[:archived_at] = nil if @record.respond_to?(:archived_at)

      @record.update!(attrs)
      audit!("public_content.published", from: from_status, to: "published")
      @record
    end

    def unpublish!
      ensure_transition!(from: %w[published], to: "approved")
      @record.update!(
        status: "approved",
        updated_by_membership: @membership
      )
      audit!("public_content.unpublished", from: "published", to: "approved")
      @record
    end

    def archive!
      ensure_transition!(from: %w[published approved draft in_review], to: "archived")
      from = @record.status
      @record.update!(
        status: "archived",
        archived_at: Time.current,
        updated_by_membership: @membership
      )
      audit!("public_content.archived", from: from, to: "archived")
      @record
    end

    private

      def ensure_transition!(from:, to:)
        raise InvalidTransition, "Cannot move from #{@record.status} to #{to}" unless from.include?(@record.status)
      end

      def audit!(event_type, from:, to:)
        subject_key = if @record.is_a?(Service)
          @record.slug
        else
          @record.page_key
        end
        AuditEvent.record!(
          event_type: event_type,
          organization: @record.organization,
          actor_membership: @membership,
          subject: @record,
          metadata: {
            "content_kind" => @record.class.name,
            "subject_key" => subject_key,
            "from_status" => from,
            "to_status" => to
          }
        )
      end
  end
end

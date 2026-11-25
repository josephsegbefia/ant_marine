# frozen_string_literal: true

module Staff
  # What one staff member sees on the team overview. Everything is read through the same
  # policies and scopes as the full pages, so the overview never shows more than they could open.
  class OverviewSummary
    WORK_LIMIT = 6
    UPDATES_LIMIT = 5

    Stat = Struct.new(:key, :label, :value, :caption, keyword_init: true)
    WorkItem = Struct.new(:kind, :record, :title, :detail, :badge, :badge_variant, :sort_at, keyword_init: true)

    attr_reader :membership

    def initialize(membership)
      @membership = membership
    end

    def stats
      @stats ||= [
        (new_enquiries_stat if team_enquiries?),
        (assigned_stat if enquiries?),
        (approvals_stat if approver?),
        unread_stat
      ].compact
    end

    def work_items
      all_work_items.first(WORK_LIMIT)
    end

    def more_work_count
      [ all_work_items.size - WORK_LIMIT, 0 ].max
    end

    def recent_updates
      @recent_updates ||= notifications.recent_first.limit(UPDATES_LIMIT).to_a
    end

    def enquiries?
      ServiceInquiryPolicy.new(membership, ServiceInquiry).index?
    end

    def quotations?
      allowed?("quotes.view_all")
    end

    private

      def all_work_items
        @all_work_items ||= (assigned_enquiry_items + returned_quote_items + approval_items + unsent_quote_items)
                              .sort_by(&:sort_at)
      end

      def new_enquiries_stat
        fresh = inquiries.where(current_status: "submitted")
        today = fresh.where(submitted_at: Time.current.all_day).count
        Stat.new(key: :new_enquiries, label: "New enquiries", value: fresh.count,
                 caption: today.zero? ? "Need a first review" : "#{today} received today")
      end

      def assigned_stat
        Stat.new(key: :assigned, label: "Assigned to me", value: my_open_enquiries.count, caption: "Open enquiries you look after")
      end

      def approvals_stat
        Stat.new(key: :approvals, label: "Waiting for your approval", value: approvable_quotes.size, caption: "Quotations to review")
      end

      def unread_stat
        Stat.new(key: :unread, label: "Unread notifications", value: notifications.unread.count, caption: "Updates for you")
      end

      def assigned_enquiry_items
        return [] unless enquiries?

        my_open_enquiries.order(:submitted_at).limit(WORK_LIMIT).map do |inquiry|
          WorkItem.new(kind: :enquiry, record: inquiry, title: inquiry.company_name,
                       detail: "Enquiry #{inquiry.reference_number} · #{inquiry.requested_service_label}",
                       badge: inquiry.status_label, badge_variant: enquiry_badge_variant(inquiry.current_status),
                       sort_at: inquiry.submitted_at)
        end
      end

      def returned_quote_items
        return [] unless allowed?("quotes.create")

        quotes.where(status: "returned_for_correction").joins(:current_revision)
              .where(quote_revisions: { prepared_by_membership_id: membership.id })
              .includes(:current_revision, :client_organization).limit(WORK_LIMIT).map do |quote|
          quote_item(quote, badge: "Returned for changes", variant: "ant-badge--warn")
        end
      end

      def approval_items
        return [] unless approver?

        approvable_quotes.first(WORK_LIMIT).map do |quote|
          quote_item(quote, badge: "Needs your approval", variant: "ant-badge--blue")
        end
      end

      def unsent_quote_items
        return [] unless quotations? && allowed?("quotes.send")

        quotes.where(status: "approved_for_issuance").includes(:current_revision, :client_organization)
              .limit(WORK_LIMIT).map do |quote|
          quote_item(quote, badge: "Approved — not sent", variant: "ant-badge--teal")
        end
      end

      def quote_item(quote, badge:, variant:)
        WorkItem.new(kind: :quote, record: quote, title: quote.display_title,
                     detail: "Quotation #{quote.reference_number} · #{quote.client_label}",
                     badge: badge, badge_variant: variant, sort_at: quote.updated_at)
      end

      def enquiry_badge_variant(status)
        case status
        when "submitted" then "ant-badge--blue"
        when "under_review", "needs_clarification" then "ant-badge--warn"
        when "qualified" then "ant-badge--teal"
        else "ant-badge--muted"
        end
      end

      def approvable_quotes
        return [] unless quotations?

        @approvable_quotes ||= quotes.where(status: "pending_review")
                                     .includes(:current_revision, :client_organization).order(:updated_at).to_a
                                     .select { |quote| QuotePolicy.new(membership, quote).approve? }
      end

      def approver?
        quotations? && allowed?("quotes.approve")
      end

      def team_enquiries?
        allowed?("inquiries.view_all")
      end

      def my_open_enquiries
        inquiries.open_requests.where(assigned_membership_id: membership.id)
      end

      def inquiries
        ServiceInquiryPolicy::Scope.new(membership, ServiceInquiry.all).resolve
      end

      def quotes
        QuotePolicy::Scope.new(membership, Quote.all).resolve
      end

      def notifications
        StaffNotificationPolicy::Scope.new(membership, StaffNotification.all).resolve
      end

      def allowed?(key)
        @permissions ||= Authorization::EffectivePermissions.new(membership)
        @permissions.allowed?(key)
      end
  end
end

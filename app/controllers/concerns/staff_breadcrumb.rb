# frozen_string_literal: true

module StaffBreadcrumb
  extend ActiveSupport::Concern

  included do
    helper_method :staff_breadcrumb_crumbs, :staff_breadcrumb_current
  end

  private

    def assign_staff_breadcrumb(crumbs:, current:)
      @staff_breadcrumb_crumbs = crumbs
      @staff_breadcrumb_current = current
    end

    def staff_breadcrumb_crumbs
      @staff_breadcrumb_crumbs || []
    end

    def staff_breadcrumb_current
      @staff_breadcrumb_current
    end
end

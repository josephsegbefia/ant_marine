module Staff
  class BaseController < ApplicationController
    include PortalAccess
    include StaffBreadcrumb

    before_action :require_staff_portal_access

    layout "staff_portal"
  end
end

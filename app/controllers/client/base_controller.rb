module Client
  class BaseController < ApplicationController
    include PortalAccess

    before_action :require_client_portal_access

    layout "application"
  end
end

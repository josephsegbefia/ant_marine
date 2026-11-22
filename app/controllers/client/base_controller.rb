module Client
  class BaseController < ApplicationController
    include PortalAccess

    before_action :require_client_portal_access

    layout "client_portal"
  end
end

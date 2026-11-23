# frozen_string_literal: true

class HomeController < ApplicationController
  layout "public_site"
  allow_unauthenticated_access only: :index
  before_action :redirect_signed_in_portal_users, only: :index

  def index
    @homepage_page = PublicSitePage.find_published_by_key("homepage")
    @homepage = PublicContent::HomepagePresenter.new(@homepage_page)
    @featured_services = Service.published_catalogue.for_ant_marine
      .order(:published_display_order, :display_order, :title)
      .limit(3)
    @seo_title = @homepage.seo_title
    @seo_description = @homepage.seo_description
  end

  private

    def redirect_signed_in_portal_users
      return unless authenticated? && Current.membership&.portal_access?

      if Current.membership.staff_domain?
        redirect_to staff_root_path
      elsif Current.membership.client_domain?
        redirect_to client_root_path
      end
    end
end

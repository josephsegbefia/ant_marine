class HomeController < ApplicationController
  allow_unauthenticated_access only: :index
  layout "public_site", only: :index

  def index
    if authenticated?
      redirect_to default_post_login_path
    end
  end
end

class HomeController < ApplicationController
  allow_unauthenticated_access only: :index

  def index
    if authenticated?
      redirect_to default_post_login_path
    else
      redirect_to new_session_path
    end
  end
end

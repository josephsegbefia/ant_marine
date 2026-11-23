# frozen_string_literal: true

module Public
  class BaseController < ApplicationController
    layout "public_site"
    allow_unauthenticated_access
  end
end

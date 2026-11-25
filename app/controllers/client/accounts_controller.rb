# frozen_string_literal: true

module Client
  class AccountsController < BaseController
    def show
      @user = Current.user
      @membership = Current.membership
      @organization = @membership.organization
    end
  end
end

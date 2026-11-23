# frozen_string_literal: true

module Staff
  module Website
    class BaseController < Staff::BaseController
      before_action :set_ant_marine_organization

      private

        def set_ant_marine_organization
          @organization = Organization.ant_marine!
        end
    end
  end
end

# frozen_string_literal: true

module Invitations
  # Kept so older references resolve to the notification seal.
  module TokenSeal
    def self.seal(...)
      Notifications::InvitationTokenSeal.seal(...)
    end

    def self.open(...)
      Notifications::InvitationTokenSeal.open(...)
    end
  end
end

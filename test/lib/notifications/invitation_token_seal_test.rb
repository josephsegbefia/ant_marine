# frozen_string_literal: true

require "test_helper"

class NotificationsInvitationTokenSealTest < ActiveSupport::TestCase
  setup do
    @raw_token = "plain-invite-token-#{SecureRandom.hex(8)}"
    @expires_at = 7.days.from_now
  end

  test "sealed payload does not contain the raw token" do
    sealed = Notifications::InvitationTokenSeal.seal(@raw_token, expires_at: @expires_at)

    assert_not_includes sealed, @raw_token
    assert_equal @raw_token, Notifications::InvitationTokenSeal.open(sealed)
  end

  test "opaque bytes cannot be decoded to reveal the token without the app secret" do
    sealed = Notifications::InvitationTokenSeal.seal(@raw_token, expires_at: @expires_at)
    decoded = Base64.urlsafe_decode64(sealed) rescue Base64.strict_decode64(sealed) rescue nil

    assert_not_includes sealed, @raw_token
    assert decoded.nil? || !decoded.include?(@raw_token)
  end

  test "tampered envelope is rejected" do
    sealed = Notifications::InvitationTokenSeal.seal(@raw_token, expires_at: @expires_at)
    tampered = sealed.sub(/./, sealed[-1] == "a" ? "b" : "a")

    assert_nil Notifications::InvitationTokenSeal.open(tampered)
  end

  test "expired envelope is rejected" do
    expires_at = 2.hours.from_now
    sealed = Notifications::InvitationTokenSeal.seal(@raw_token, expires_at: expires_at)

    travel 3.hours do
      assert_nil Notifications::InvitationTokenSeal.open(sealed)
    end
  end
end

module SessionTestHelper
  def sign_in_as(user, membership: nil)
    membership ||= user.memberships.portal_eligible.first
    Current.session = Session.issue_for!(
      user: user,
      ip_address: "127.0.0.1",
      user_agent: "test",
      membership: membership
    )
    Current.membership = membership

    ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
      cookie_jar.signed[:session_id] = Current.session.id
      cookies["session_id"] = cookie_jar[:session_id]
    end
  end

  def sign_out
    Current.session&.revoke!
    Current.session = nil
    Current.membership = nil
    cookies.delete("session_id")
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SessionTestHelper
end

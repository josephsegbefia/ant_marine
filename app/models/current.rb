class Current < ActiveSupport::CurrentAttributes
  attribute :session, :membership

  delegate :user, to: :session, allow_nil: true

  def membership=(value)
    super
    session&.update!(membership: value) if session && value && session.membership_id != value.id
  end
end

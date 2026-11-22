# frozen_string_literal: true

module PublicLayoutHelper
  def public_nav_active?(section)
    (content_for?(:public_nav) ? content_for(:public_nav) : "home") == section.to_s
  end
end

# frozen_string_literal: true

Rails.application.config.action_text.disable_direct_uploads = true

Rails.application.config.to_prepare do
  ActionText::ContentHelper.allowed_tags = PublicContent::RichText::ALLOWED_TAGS
  ActionText::ContentHelper.allowed_attributes = PublicContent::RichText::ALLOWED_ATTRIBUTES
end

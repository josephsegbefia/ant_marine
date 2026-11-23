# frozen_string_literal: true

# After migrations remove legacy body columns, long-lived dev servers may keep
# stale column metadata until reload. Refresh on code prepare in development.
Rails.application.config.to_prepare do
  next unless Rails.env.development?

  refreshable = [
    Article, CaseStudy, TrainingOffering, PublicResource, Service, PublicSitePage
  ].select(&:table_exists?)

  refreshable.each(&:reset_column_information)
end

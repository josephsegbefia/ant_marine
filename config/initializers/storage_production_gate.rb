# frozen_string_literal: true

Rails.application.config.after_initialize do
  Storage::ProductionServiceGate.verify!(
    service_name: Rails.application.config.active_storage.service
  )
end

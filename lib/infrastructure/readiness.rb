# frozen_string_literal: true

module Infrastructure
  module Readiness
    CheckResult = Data.define(:name, :ok, :detail)

    module_function

    def call
      [
        primary_database,
        permission_catalogue,
        mail_delivery,
        storage_configuration
      ]
    end

    def ready?
      call.all?(&:ok)
    end

    def primary_database
      ActiveRecord::Base.connection.select_value("SELECT 1")
      CheckResult.new(name: "primary_database", ok: true, detail: "connected")
    rescue StandardError => e
      CheckResult.new(name: "primary_database", ok: false, detail: e.class.name)
    end

    def permission_catalogue
      if Authorization::CatalogueSeeder.catalogue_present?
        CheckResult.new(name: "permission_catalogue", ok: true, detail: "seeded")
      else
        CheckResult.new(name: "permission_catalogue", ok: false, detail: "missing_or_stale")
      end
    rescue StandardError => e
      CheckResult.new(name: "permission_catalogue", ok: false, detail: e.class.name)
    end

    def mail_delivery
      label = Notifications::MailDelivery.readiness_label
      ok = !Rails.env.production? || Notifications::MailDelivery.configured?
      CheckResult.new(name: "mail_delivery", ok: ok, detail: label)
    end

    def storage_configuration
      Storage::ProductionServiceGate.verify!(service_name: Rails.application.config.active_storage.service)
      CheckResult.new(name: "storage_configuration", ok: true, detail: Rails.application.config.active_storage.service.to_s)
    rescue Storage::ProductionServiceGate::Blocked => e
      CheckResult.new(name: "storage_configuration", ok: false, detail: e.message.lines.first&.strip)
    end
  end
end

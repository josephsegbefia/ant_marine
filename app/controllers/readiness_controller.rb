# frozen_string_literal: true

class ReadinessController < ActionController::API
  def show
    checks = Infrastructure::Readiness.call
    payload = {
      status: checks.all?(&:ok) ? "ready" : "not_ready",
      checks: checks.map { |c| { name: c.name, ok: c.ok, detail: c.detail } }
    }

    render json: payload, status: (payload[:status] == "ready" ? :ok : :service_unavailable)
  end
end

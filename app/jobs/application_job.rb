class ApplicationJob < ActiveJob::Base
  # Wait until the surrounding database transaction commits before the job is visible.
  self.enqueue_after_transaction_commit = true

  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5
  retry_on Timeout::Error, Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 5

  discard_on ActiveJob::DeserializationError
end

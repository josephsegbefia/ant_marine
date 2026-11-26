ENV["RAILS_ENV"] ||= "test"
ENV["STORAGE_ENCRYPTION_KEY"] ||= "test-only-storage-encryption-secret"
ENV["STORAGE_MAX_UPLOAD_BYTES"] ||= (5 * 1024 * 1024).to_s
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"
require_relative "test_helpers/invitation_test_helper"
require_relative "test_helpers/storage_test_helper"
require_relative "test_helpers/quote_test_helper"
require_relative "test_helpers/enquiry_test_helper"
require_relative "test_helpers/delivery_test_helper"
require_relative "test_helpers/malware_scan_stub_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    parallelize_setup do
      Authorization::CatalogueSeeder.reset_seed_flag!
      Authorization::CatalogueSeeder.seed!
      PublicContent::CatalogueSeeder.seed! if Organization.exists?(kind: "ant_marine")
    end

    setup { Authorization::CatalogueSeeder.seed! unless Authorization::CatalogueSeeder.catalogue_present? }

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

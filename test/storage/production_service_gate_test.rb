# frozen_string_literal: true

require "test_helper"

class StorageProductionServiceGateTest < ActiveSupport::TestCase
  test "plain private_s3 is blocked in production" do
    with_production_env do
      error = assert_raises Storage::ProductionServiceGate::Blocked do
        Storage::ProductionServiceGate.verify!(service_name: :private_s3)
      end
      assert_match(/private_s3/i, error.message)
    end
  end

  test "encrypted_s3 is permitted in production config check" do
    with_production_env do
      assert_nothing_raised do
        Storage::ProductionServiceGate.verify!(service_name: :encrypted_s3)
      end
    end
  end

  test "local_encrypted is permitted in production" do
    with_production_env do
      assert_nothing_raised do
        Storage::ProductionServiceGate.verify!(service_name: :local_encrypted)
      end
    end
  end

  test "unencrypted disk service is blocked in production" do
    with_production_env do
      assert_raises Storage::ProductionServiceGate::Blocked do
        Storage::ProductionServiceGate.verify!(service_name: :local)
      end
    end
  end

  private

    def with_production_env
      original = Rails.env
      Rails.env = ActiveSupport::StringInquirer.new("production")
      yield
    ensure
      Rails.env = original
    end
end

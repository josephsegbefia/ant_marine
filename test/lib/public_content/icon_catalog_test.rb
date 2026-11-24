# frozen_string_literal: true

require "test_helper"

class PublicContent::IconCatalogTest < ActiveSupport::TestCase
  test "resolve returns ship for blank or unknown keys" do
    assert_equal "ship", PublicContent::IconCatalog.resolve(nil)
    assert_equal "ship", PublicContent::IconCatalog.resolve("not-a-key")
  end

  test "all catalog keys are valid" do
    PublicContent::IconCatalog.keys.each do |key|
      assert PublicContent::IconCatalog.valid?(key)
    end
  end

  test "legacy icon keys still valid" do
    %w[ship brief leaf wrench file book].each do |key|
      assert PublicContent::IconCatalog.valid?(key)
    end
  end
end

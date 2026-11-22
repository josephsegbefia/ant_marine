# frozen_string_literal: true

require "test_helper"

class StorageEncryptionTest < ActiveSupport::TestCase
  test "encrypt decrypt round trip" do
    plaintext = "Hello PoC storage proof."
    ciphertext = Storage::Encryption.encrypt(plaintext)

    assert_not_includes ciphertext, plaintext
    assert_equal plaintext, Storage::Encryption.decrypt(ciphertext)
  end

  test "tampered ciphertext is rejected" do
    ciphertext = Storage::Encryption.encrypt("secret")
    tampered = ciphertext.sub(/A/, "B")

    assert_nil Storage::Encryption.decrypt(tampered)
  end

  test "wrong key cannot decrypt" do
    ciphertext = Storage::Encryption.encrypt("secret")
    original = ENV["STORAGE_ENCRYPTION_KEY"]
    ENV["STORAGE_ENCRYPTION_KEY"] = "different-secret-material"

    begin
      assert_nil Storage::Encryption.decrypt(ciphertext)
    ensure
      ENV["STORAGE_ENCRYPTION_KEY"] = original
    end
  end

  test "at rest bytes do not contain plaintext" do
    membership = memberships(:super_admin_membership)
    bytes = "Hello PoC storage proof."
    asset = upload_storage_proof!(membership: membership, bytes: bytes)

    blob = asset.active_storage_blob
    path = blob.service.send(:path_for, blob.key)
    on_disk = File.binread(path)

    assert_not_includes on_disk, bytes
    assert_equal bytes, Storage::SecureDownload.call(asset: asset).plaintext
  end
end

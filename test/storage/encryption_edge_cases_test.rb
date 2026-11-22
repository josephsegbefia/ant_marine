# frozen_string_literal: true

require "test_helper"

class StorageEncryptionEdgeCasesTest < ActiveSupport::TestCase
  test "binary payload round trips" do
    binary = (0..255).map(&:chr).join.b
    ciphertext = Storage::Encryption.encrypt(binary)

    assert_equal binary, Storage::Encryption.decrypt(ciphertext)
  end

  test "truncated ciphertext fails closed" do
    ciphertext = Storage::Encryption.encrypt("payload")
    assert_nil Storage::Encryption.decrypt(ciphertext.byteslice(0, 12))
  end

  test "corrupted envelope version fails closed" do
    ciphertext = Storage::Encryption.encrypt("payload")
    tampered = ciphertext.sub("AMST1", "AMST9")

    assert_nil Storage::Encryption.decrypt(tampered)
  end

  test "download_chunk returns plaintext slice" do
    membership = memberships(:super_admin_membership)
    bytes = "0123456789abcdefghijklmnopqrstuvwxyz"
    asset = upload_storage_proof!(membership: membership, bytes: bytes)
    blob = asset.active_storage_blob

    chunk = blob.download_chunk(0...10)
    assert_equal "0123456789", chunk
  end
end

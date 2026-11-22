# frozen_string_literal: true

require "active_storage/service/disk_service"

class ActiveStorage::Service::EncryptedDiskService < ActiveStorage::Service
  def initialize(root:, public: false, **options)
    @root = root
    @disk = ActiveStorage::Service::DiskService.new(root: root, public: public, **options)
  end

  def upload(key, io, checksum: nil, **)
    plaintext = io.read
    ciphertext = ::Storage::Encryption.encrypt(plaintext)
    encrypted_io = StringIO.new(ciphertext)
    encrypted_checksum = OpenSSL::Digest::MD5.base64digest(ciphertext)
    @disk.upload(key, encrypted_io, checksum: encrypted_checksum, **)
  end

  def download(key, &block)
    ciphertext = @disk.download(key)
    plaintext = ::Storage::Encryption.decrypt(ciphertext)
    raise ActiveStorage::IntegrityError, "decryption failed" if plaintext.nil?

    if block_given?
      yield plaintext.b
    else
      plaintext
    end
  end

  def download_chunk(key, range)
    plaintext = download(key)
    plaintext.byteslice(range)
  end

  def delete(key)
    @disk.delete(key)
  end

  def delete_prefixed(prefix)
    @disk.delete_prefixed(prefix)
  end

  def exist?(key)
    @disk.exist?(key)
  end

  def path_for(key)
    @disk.send(:path_for, key)
  end

  def url(*)
    raise NotImplementedError, "direct URLs are disabled for encrypted storage"
  end

  def url_for_direct_upload(*)
    raise NotImplementedError, "direct uploads are disabled for encrypted storage"
  end

  def headers_for_direct_upload(*)
    raise NotImplementedError, "direct uploads are disabled for encrypted storage"
  end
end

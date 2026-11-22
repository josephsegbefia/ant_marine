# frozen_string_literal: true

require "active_storage/service/s3_service"

class ActiveStorage::Service::EncryptedS3Service < ActiveStorage::Service
  def initialize(bucket:, upload: {}, public: false, **options)
    raise ArgumentError, "encrypted S3 must be private" if public

    @s3 = ActiveStorage::Service::S3Service.new(bucket: bucket, upload: upload, public: false, **options)
  end

  def upload(key, io, checksum: nil, **options)
    plaintext = io.read
    ciphertext = ::Storage::Encryption.encrypt(plaintext)
    encrypted_io = StringIO.new(ciphertext)
    encrypted_checksum = OpenSSL::Digest::MD5.base64digest(ciphertext)
    @s3.upload(key, encrypted_io, checksum: encrypted_checksum, **options)
  end

  def download(key, &block)
    ciphertext = @s3.download(key)
    plaintext = ::Storage::Encryption.decrypt(ciphertext)
    raise ActiveStorage::IntegrityError, "decryption failed" if plaintext.nil?

    if block_given?
      yield plaintext.b
    else
      plaintext
    end
  end

  def download_chunk(key, range)
    download(key).byteslice(range)
  end

  def delete(key)
    @s3.delete(key)
  end

  def delete_prefixed(prefix)
    @s3.delete_prefixed(prefix)
  end

  def exist?(key)
    @s3.exist?(key)
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

# frozen_string_literal: true

module Storage
  class ContentValidator
    class Error < StandardError; end
    class TypeNotAllowed < Error; end
    class TooLarge < Error; end
    class FilenameInvalid < Error; end

    ALLOWED_TYPES = %w[text/plain application/pdf image/png image/jpeg].freeze
    MAX_BYTES = -> { ENV.fetch("STORAGE_MAX_UPLOAD_BYTES", 5.megabytes).to_i }

    def self.call(filename:, io:)
      new(filename: filename, io: io).call
    end

    def initialize(filename:, io:)
      @filename = filename.to_s
      @io = io
    end

    def call
      validate_filename!
      @bytes = @io.read
      @io.rewind if @io.respond_to?(:rewind)
      raise TooLarge, "file exceeds size limit" if @bytes.bytesize > MAX_BYTES.call

      detected = Marcel::MimeType.for(StringIO.new(@bytes), name: @filename, declared_type: declared_type)
      raise TypeNotAllowed, "file type not allowed" unless ALLOWED_TYPES.include?(detected)

      { content_type: detected, byte_size: @bytes.bytesize, bytes: @bytes }
    end

    private

      def validate_filename!
        base = File.basename(@filename)
        raise FilenameInvalid, "invalid filename" if base.blank? || base != @filename
        raise FilenameInvalid, "invalid filename" if base.include?("..") || base.include?("/") || base.include?("\\")
      end

      def declared_type
        Marcel::MimeType.for(name: @filename)
      rescue StandardError
        nil
      end
  end
end

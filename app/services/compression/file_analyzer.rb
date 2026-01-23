# frozen_string_literal: true

module Compression
  class FileAnalyzer
    COMPRESSIBLE_IMAGE_TYPES = %w[
      image/jpeg
      image/png
      image/webp
      image/heic
      image/heif
    ].freeze

    ALREADY_COMPRESSED_TYPES = %w[
      application/zip
      application/x-7z-compressed
      application/vnd.rar
      application/x-tar
      application/gzip
      application/x-bzip2
    ].freeze

    SKIP_COMPRESSION_TYPES = %w[
      image/gif
    ].freeze

    COMPRESSIBLE_DOCUMENT_TYPES = %w[
      application/pdf
    ].freeze

    def initialize(attachment)
      @attachment = attachment
    end

    def within_limits?(channel_limit)
      return true unless channel_limit.supported

      file_size <= channel_limit.max_size
    end

    def compressible?
      return false if already_compressed?
      return false if skip_compression?

      case file_type
      when :image then compressible_image?
      when :audio, :video then false # Phase 2: requires ffmpeg
      when :file then compressible_document?
      else false
      end
    end

    def file_size
      @attachment.file.byte_size
    end

    def content_type
      @attachment.file.content_type
    end

    def file_type
      @attachment.file_type.to_sym
    end

    private

    def already_compressed?
      ALREADY_COMPRESSED_TYPES.include?(content_type)
    end

    def skip_compression?
      SKIP_COMPRESSION_TYPES.include?(content_type)
    end

    def compressible_image?
      COMPRESSIBLE_IMAGE_TYPES.include?(content_type)
    end

    def compressible_document?
      COMPRESSIBLE_DOCUMENT_TYPES.include?(content_type)
    end
  end
end

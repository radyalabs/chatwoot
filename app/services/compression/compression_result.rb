# frozen_string_literal: true

module Compression
  class CompressionResult
    attr_reader :status, :io, :content_type, :filename,
                :original_size, :compressed_size, :reason

    def self.compressed(io:, original_size:, compressed_size:, content_type:, filename:)
      new(
        status: :compressed,
        io: io,
        original_size: original_size,
        compressed_size: compressed_size,
        content_type: content_type,
        filename: filename
      )
    end

    def self.skipped(reason)
      new(status: :skipped, reason: reason)
    end

    def self.failed(reason)
      new(status: :failed, reason: reason)
    end

    def initialize(status:, io: nil, original_size: nil, compressed_size: nil,
                   content_type: nil, filename: nil, reason: nil)
      @status = status
      @io = io
      @original_size = original_size
      @compressed_size = compressed_size
      @content_type = content_type
      @filename = filename
      @reason = reason
    end

    def compressed?
      @status == :compressed
    end

    def skipped?
      @status == :skipped
    end

    def failed?
      @status == :failed
    end

    def compression_ratio
      return 0 unless compressed? && original_size.positive?

      ((original_size - compressed_size).to_f / original_size * 100).round(2)
    end
  end
end

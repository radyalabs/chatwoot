# frozen_string_literal: true

module Compression
  class PdfCompressor < BaseCompressor
    SUPPORTED_FORMATS = %w[application/pdf].freeze

    # Compression levels for HexaPDF optimization
    COMPRESSION_LEVELS = %i[compact compress_pages].freeze

    def compress(attachment, target_size:)
      return CompressionResult.skipped('Unsupported format') unless supported?(attachment)
      return CompressionResult.skipped('HexaPDF not available') unless hexapdf_available?

      with_tempfile(attachment) do |source_file|
        result_io = compress_pdf(source_file, attachment, target_size)

        if result_io
          CompressionResult.compressed(
            io: result_io,
            original_size: attachment.file.byte_size,
            compressed_size: result_io.size,
            content_type: 'application/pdf',
            filename: attachment.file.filename.to_s
          )
        else
          CompressionResult.skipped('PDF already optimized or compression ineffective')
        end
      end
    end

    private

    def supported?(attachment)
      SUPPORTED_FORMATS.include?(attachment.file.content_type)
    end

    def hexapdf_available?
      require 'hexapdf'
      true
    rescue LoadError
      false
    end

    def compress_pdf(source_file, attachment, target_size)
      original_size = attachment.file.byte_size

      # Skip if already within target size
      return nil if original_size <= target_size

      output_file = Tempfile.new(['compressed', '.pdf'])
      output_file.binmode

      begin
        doc = HexaPDF::Document.open(source_file.path)

        # Apply optimization options
        doc.task(:optimize,
                 compact: true,
                 compress_pages: true,
                 object_streams: :generate,
                 xref_streams: :generate,
                 unused_pages: true,
                 duplicate_fonts: true)

        doc.write(output_file.path)
        output_file.rewind

        compressed_size = File.size(output_file.path)

        # Only return compressed version if it's actually smaller
        # and within target (or at least significantly smaller)
        if compressed_size < original_size && (compressed_size <= target_size || compression_worthwhile?(original_size, compressed_size))
          create_result_io(output_file.path)
        end
      rescue HexaPDF::Error => e
        Rails.logger.warn("[Compression] PDF compression failed: #{e.message}")
        nil
      ensure
        output_file.close
        output_file.unlink
      end
    end

    # Consider compression worthwhile if we achieved at least 10% reduction
    def compression_worthwhile?(original_size, compressed_size)
      reduction_ratio = (original_size - compressed_size).to_f / original_size
      reduction_ratio >= 0.10
    end
  end
end

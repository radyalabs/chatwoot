# frozen_string_literal: true

require 'image_processing/vips'

module Compression
  class ImageCompressor < BaseCompressor
    QUALITY_STEPS = [85, 70, 55, 40].freeze
    MAX_DIMENSION = 2048
    RESIZE_STEPS = [1600, 1200, 800].freeze

    SUPPORTED_FORMATS = %w[
      image/jpeg
      image/png
      image/webp
      image/heic
      image/heif
    ].freeze

    def compress(attachment, target_size:)
      return CompressionResult.skipped('Unsupported format') unless supported?(attachment)

      with_tempfile(attachment) do |source_file|
        compress_image(source_file, attachment, target_size)
      end
    rescue Vips::Error => e
      Rails.logger.error("[Compression::ImageCompressor] Vips error: #{e.message}")
      CompressionResult.failed("Image processing failed: #{e.message}")
    rescue StandardError => e
      Rails.logger.error("[Compression::ImageCompressor] Unexpected error: #{e.message}")
      CompressionResult.failed("Compression failed: #{e.message}")
    end

    private

    def supported?(attachment)
      SUPPORTED_FORMATS.include?(attachment.file.content_type)
    end

    def compress_image(source_file, attachment, target_size)
      original_size = attachment.file.byte_size

      # Strategy 1: Try quality reduction with optional initial resize
      result_path = try_quality_reduction(source_file.path, target_size)
      return build_result(result_path, original_size, attachment) if result_path

      # Strategy 2: Progressive resize with lowest quality
      result_path = try_progressive_resize(source_file.path, target_size)
      return build_result(result_path, original_size, attachment) if result_path

      CompressionResult.failed('Could not compress below target size')
    end

    def try_quality_reduction(source_path, target_size)
      image = Vips::Image.new_from_file(source_path, access: :sequential)

      # First resize if dimensions are too large
      pipeline = ImageProcessing::Vips.source(source_path)
      if image.width > MAX_DIMENSION || image.height > MAX_DIMENSION
        pipeline = pipeline.resize_to_limit(MAX_DIMENSION, MAX_DIMENSION)
      end

      # Try each quality level
      QUALITY_STEPS.each do |quality|
        result = pipeline
                 .convert('jpeg')
                 .saver(quality: quality)
                 .call

        return result.path if File.size(result.path) <= target_size
      end

      nil
    end

    def try_progressive_resize(source_path, target_size)
      RESIZE_STEPS.each do |max_dim|
        result = ImageProcessing::Vips
                 .source(source_path)
                 .resize_to_limit(max_dim, max_dim)
                 .convert('jpeg')
                 .saver(quality: QUALITY_STEPS.last)
                 .call

        return result.path if File.size(result.path) <= target_size
      end

      nil
    end

    def build_result(result_path, original_size, attachment)
      compressed_size = File.size(result_path)
      io = create_result_io(result_path)

      CompressionResult.compressed(
        io: io,
        original_size: original_size,
        compressed_size: compressed_size,
        content_type: 'image/jpeg',
        filename: compressed_filename(attachment)
      )
    ensure
      File.unlink(result_path) if result_path && File.exist?(result_path)
    end

    def compressed_filename(attachment)
      basename = File.basename(attachment.file.filename.to_s, '.*')
      "#{basename}.jpg"
    end
  end
end

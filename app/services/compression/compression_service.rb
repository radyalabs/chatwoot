# frozen_string_literal: true

module Compression
  class CompressionService
    def self.compress(attachment:, channel_type:, options: {})
      new(attachment, channel_type, options).perform
    end

    def initialize(attachment, channel_type, options = {})
      @attachment = attachment
      @channel_type = channel_type
      @options = options
    end

    def perform
      return skip('No file attached') unless @attachment.file.attached?

      limits = ChannelLimits.for(@channel_type, @attachment.file_type)
      analyzer = FileAnalyzer.new(@attachment)

      return skip('File within channel limits') if analyzer.within_limits?(limits)
      return skip('File type not compressible') unless analyzer.compressible?

      compressor = compressor_for(@attachment.file_type)
      result = compressor.compress(@attachment, target_size: limits.max_size)

      log_result(result)
      result
    end

    private

    def compressor_for(file_type)
      case file_type.to_sym
      when :image then ImageCompressor.new(@options)
      when :audio then NullCompressor.new(@options) # Phase 2: AudioCompressor
      when :video then NullCompressor.new(@options) # Phase 2: VideoCompressor
      when :file then compressor_for_document
      else NullCompressor.new(@options)
      end
    end

    def compressor_for_document
      content_type = @attachment.file.content_type

      case content_type
      when 'application/pdf' then PdfCompressor.new(@options)
      else NullCompressor.new(@options)
      end
    end

    def skip(reason)
      CompressionResult.skipped(reason)
    end

    def log_result(result)
      if result.compressed?
        Rails.logger.info(
          "[Compression] Compressed file from #{human_size(result.original_size)} " \
          "to #{human_size(result.compressed_size)} (#{result.compression_ratio}% reduction)"
        )
      elsif result.failed?
        Rails.logger.warn("[Compression] Failed to compress: #{result.reason}")
      end
    end

    def human_size(bytes)
      ActiveSupport::NumberHelper.number_to_human_size(bytes)
    end
  end
end

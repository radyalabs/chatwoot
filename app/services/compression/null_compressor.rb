# frozen_string_literal: true

module Compression
  class NullCompressor < BaseCompressor
    def compress(_attachment, target_size:)
      CompressionResult.skipped('File type not supported for compression')
    end
  end
end

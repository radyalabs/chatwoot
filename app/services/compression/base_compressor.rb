# frozen_string_literal: true

module Compression
  class BaseCompressor
    def initialize(options = {})
      @options = options
    end

    def compress(attachment, target_size:)
      raise NotImplementedError, 'Subclasses must implement #compress'
    end

    protected

    def with_tempfile(attachment, &block)
      extension = File.extname(attachment.file.filename.to_s)
      basename = File.basename(attachment.file.filename.to_s, extension)

      Tempfile.create([basename, extension]) do |tempfile|
        tempfile.binmode
        tempfile.write(attachment.file.download)
        tempfile.rewind
        yield tempfile
      end
    end

    def create_result_io(file_path)
      StringIO.new(File.binread(file_path))
    end
  end
end

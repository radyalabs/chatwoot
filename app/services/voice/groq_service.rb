require 'net/http'
require 'uri'

class Voice::GroqService
  GROQ_API_URL = 'https://api.groq.com/openai/v1/audio/transcriptions'.freeze
  SUPPORTED_FORMATS = %w[.ogg .oga .mp3 .mp4 .mpeg .mpga .m4a .wav .webm .flac].freeze
  MAX_FILE_SIZE = 25.megabytes

  def initialize
    @api_key = ENV.fetch('GROQ_API_KEY', nil)
  end

  def transcribe(io, filename: 'audio.ogg', language: nil)
    if @api_key.blank?
      Rails.logger.error '[VOICE][TRANSCRIBE][ERROR] GROQ_API_KEY is not configured'
      return nil
    end

    Rails.logger.info(
      "[VOICE][TRANSCRIBE] Starting Groq Whisper transcription | " \
      "filename=#{filename} | language=#{language || 'auto'}"
    )

    uri = URI.parse(GROQ_API_URL)

    boundary = "----RubyFormBoundary#{SecureRandom.hex(16)}"

    body = build_multipart_body(io, filename, boundary, language)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 30

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Authorization'] = "Bearer #{@api_key}"
    request['Content-Type'] = "multipart/form-data; boundary=#{boundary}"
    request.body = body

    response = http.request(request)

    if response.is_a?(Net::HTTPSuccess)
      text = parse_response(response)
      Rails.logger.info(
        "[VOICE][TRANSCRIBE] Transcription successful | " \
        "text_length=#{text.length} | preview=#{text[0..100].inspect}"
      )
      text.strip.presence
    else
      Rails.logger.error(
        "[VOICE][TRANSCRIBE][ERROR] Groq API failed | " \
        "status=#{response.code} | body=#{response.body&.first(500)}"
      )
      nil
    end
  rescue StandardError => e
    Rails.logger.error(
      "[VOICE][TRANSCRIBE][ERROR] Transcription exception | " \
      "error=#{e.class}: #{e.message}"
    )
    nil
  end

  private

  def build_multipart_body(io, filename, boundary, language)
    io.rewind if io.respond_to?(:rewind)

    body = +""

    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"model\"\r\n\r\n"
    body << "whisper-large-v3-turbo\r\n"

    if language.present?
      body << "--#{boundary}\r\n"
      body << "Content-Disposition: form-data; name=\"language\"\r\n\r\n"
      body << "#{language}\r\n"
    end

    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n"
    body << "text\r\n"

    content_type = detect_content_type(filename)

    body << "--#{boundary}\r\n"
    body << "Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"\r\n"
    body << "Content-Type: #{content_type}\r\n\r\n"
    body << io.read
    body << "\r\n"

    body << "--#{boundary}--\r\n"

    io.rewind if io.respond_to?(:rewind)

    body.force_encoding('BINARY')
  end

  def detect_content_type(filename)
    ext = File.extname(filename).downcase
    case ext
    when '.ogg', '.oga' then 'audio/ogg'
    when '.mp3' then 'audio/mpeg'
    when '.mp4', '.m4a' then 'audio/mp4'
    when '.wav' then 'audio/wav'
    when '.webm' then 'audio/webm'
    when '.flac' then 'audio/flac'
    when '.mpeg', '.mpga' then 'audio/mpeg'
    else 'audio/ogg'
    end
  end

  def parse_response(response)
    content_type = response['content-type'] || ''
    if content_type.include?('application/json')
      parsed = JSON.parse(response.body)
      parsed['text'] || ''
    else
      response.body.to_s
    end
  end
end
require 'multipart/post'

class WhatsappUnofficial::Providers::GowaService < WhatsappUnofficial::Providers::BaseService
  def send_message(message)
    attachments = message[:attachments] || []

    if attachments.any?
      send_attachment_message(message, attachments)
    elsif message[:link].present?
      send_message_link(message)
    else
      send_message_text(message)
    end
  end

  private

  def send_attachment_message(message, attachments)
    phone_number = message[:phone_number]
    caption = message[:content]

    attachments.each_with_index do |attachment, index|
      file_type = attachment[:file_type]
      download_url = attachment[:download_url]

      current_caption = index.zero? ? caption : nil

      case file_type
      when 'image'
        send_image(phone_number, attachment, caption: current_caption)
      when 'audio'
        send_audio(phone_number, download_url, caption: current_caption)
      when 'video'
        send_video(phone_number, download_url, caption: current_caption)
      when 'file'
        send_document(phone_number, attachment, caption: current_caption)
      end
    end
  end

  def send_message_text(message)
    response = HTTParty.post(
      "#{api_base_path}/send/message",
      headers: api_headers,
      body: {
        phone: "#{message[:phone_number]}@s.whatsapp.net",
        message: message[:content]
      }.to_json
    )

    process_response(response)
  end

  def send_message_link(message)
    response = HTTParty.post(
      "#{api_base_path}/send/link",
      headers: api_headers,
      body: {
        phone: "#{message[:phone_number]}@s.whatsapp.net",
        link: message[:link],
        caption: message[:content]
      }.to_json
    )

    process_response(response)
  end

  def send_image(phone_number, attachment, caption: nil) # rubocop:disable Metrics/MethodLength
    tempfile = Tempfile.new(
      [File.basename(attachment[:filename], '.*'), File.extname(attachment[:filename])]
    )

    tempfile.binmode
    tempfile.write(attachment[:io].read)
    tempfile.rewind

    body = {
      phone: phone_number,
      image: Multipart::Post::UploadIO.new(tempfile, attachment[:content_type], attachment[:filename])
    }
    body[:caption] = caption if caption

    response = HTTParty.post(
      "#{api_base_path}/send/image",
      headers: api_headers,
      body: body,
      multipart: true
    )

    process_response(response)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def send_document(phone_number, attachment, caption: nil) # rubocop:disable Metrics/MethodLength
    tempfile = Tempfile.new(
      [File.basename(attachment[:filename], '.*'), File.extname(attachment[:filename])]
    )

    tempfile.binmode
    tempfile.write(attachment[:io].read)
    tempfile.rewind

    body = {
      phone: "#{phone_number}@s.whatsapp.net",
      file: Multipart::Post::UploadIO.new(tempfile, attachment[:content_type], attachment[:filename])
    }

    body[:caption] = caption if caption

    response = HTTParty.post(
      "#{api_base_path}/send/file",
      headers: api_headers,
      body: body,
      multipart: true
    )

    process_response(response)
  ensure
    tempfile&.close
    tempfile&.unlink
  end

  def send_audio(phone_number, audio_url)
    body = {
      phone: "#{phone_number}@s.whatsapp.net",
      audio_url: audio_url
    }

    response = HTTParty.post(
      "#{api_base_path}/send/audio",
      headers: api_headers,
      body: body,
      multipart: true
    )

    process_response(response)
  end

  def send_video(phone_number, video_url, caption: nil)
    body = {
      phone: "#{phone_number}@s.whatsapp.net",
      video_url: video_url
    }
    body[:caption] = caption if caption

    response = HTTParty.post(
      "#{api_base_path}/send/video",
      headers: api_headers,
      body: body,
      multipart: true
    )

    process_response(response)
  end

  def process_response(response)
    if response.success?
      response['results']
    else
      Rails.logger.error(
        "[GOWA SEND MESSAGE ERROR] status=#{response.code} body=#{response.body}"
      )
      nil
    end
  end

  def api_headers
    {
      'Authorization' => "Basic #{ENV.fetch('GOWA_BASIC_AUTH', '')}",
      'X-Device-Id' => whatsapp_channel.device_id,
      'Content-Type' => 'application/json'
    }
  end

  def api_base_path
    # provide the environment variable when testing against sandbox : 'https://waba-sandbox.360dialog.io/v1'
    ENV.fetch('GOWA_API_URL', 'https://gowa.jangkau.ai')
  end
end

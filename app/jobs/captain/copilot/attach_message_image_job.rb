class Captain::Copilot::AttachMessageImageJob < ApplicationJob
  queue_as :default
  sidekiq_options timeout: 90

  MAX_IMAGE_SIZE = 50 * 1024 * 1024
  MAX_DOWNLOAD_TIMEOUT = 30

  def perform(message_attrs, attachment, index = nil, message_content = nil)
    attachment_data = attachment.is_a?(String) ? JSON.parse(attachment) : attachment
    title = attachment_data['title'] || ''
    url = attachment_data['url']
    return if url.blank?

    image_file = download_image(url)
    return if image_file.nil?

    return send_non_image_fallback(image_file, title, url, message_attrs, message_content) unless image?(image_file)

    attach_image(message_attrs, title, image_file, index)
  rescue JSON::ParserError => e
    Rails.logger.error "[AttachMessageImageJob] Failed to parse attachment JSON: #{e.message}"
    send_fallback_message(title, url, message_attrs, message_content)
  rescue Timeout::Error => e
    Rails.logger.error "[AttachMessageImageJob] Download timeout for image #{url}: #{e.message}"
    send_fallback_message(title, url, message_attrs, message_content)
  rescue StandardError => e
    Rails.logger.error "[AttachMessageImageJob] Failed to attach image #{url}: #{e.message}"
    send_fallback_message(title, url, message_attrs, message_content)
  end

  private

  def download_image(url)
    Timeout.timeout(MAX_DOWNLOAD_TIMEOUT) do
      Down.download(url, max_size: MAX_IMAGE_SIZE)
    end
  end

  def image?(image_file)
    image_file.content_type.present? && image_file.content_type.start_with?('image/')
  end

  def send_non_image_fallback(image_file, title, url, message_attrs, message_content)
    Rails.logger.warn "[AttachMessageImageJob] Non-image attachment (#{image_file.content_type || 'unknown'}): #{url}"
    send_fallback_message(title, url, message_attrs, message_content)
  end

  def attach_image(message_attrs, title, image_file, index)
    filename = image_filename(message_attrs, image_file.content_type, index)
    message = Message.new(message_attrs.merge(content: title))

    message.attachments.build(
      account_id: message.account_id,
      file_type: 'image',
      file: {
        io: image_file,
        filename: filename,
        content_type: image_file.content_type
      }
    )

    message.save!
    Rails.logger.info "[AttachMessageImageJob] Message #{message.id} created with attachment named #{filename}"
  end

  def image_filename(message_attrs, content_type, index)
    [
      'bot_image',
      message_attrs[:conversation_id],
      message_attrs[:account_id],
      message_attrs[:sender_id],
      index,
      Time.current.to_i
    ].join('_') + image_extension(content_type)
  end

  def image_extension(content_type)
    return '.png' if content_type == 'image/png'
    return '.gif' if content_type == 'image/gif'
    return '.webp' if content_type == 'image/webp'

    '.jpg'
  end

  def send_fallback_message(title, url, message_attrs, message_content = nil)
    return if url.blank?

    if message_content.present? && message_content.include?(url)
      Rails.logger.info "[AttachMessageImageJob] Skipping fallback - URL already in message content: #{url}"
      return
    end

    message_content = title.present? ? "#{title}\n#{url}" : url
    message = Message.new(message_attrs.merge(
                            content: message_content
                          ))
    message.save!
    Rails.logger.info "[AttachMessageImageJob] Fallback message #{message.id} created for URL: #{url}"
  end
end

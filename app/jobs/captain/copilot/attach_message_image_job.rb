class Captain::Copilot::AttachMessageImageJob < ApplicationJob
  queue_as :default
  sidekiq_options timeout: 90

  MAX_IMAGE_SIZE = 50 * 1024 * 1024
  MAX_DOWNLOAD_TIMEOUT = 30

  def perform(message_attrs, attachment, index = nil, message_content = nil)
    # Parse attachment as JSON object with title and url
    attachment_data = attachment.is_a?(String) ? JSON.parse(attachment) : attachment
    title = attachment_data['title'] || ''
    url = attachment_data['url']

    return if url.blank?

    image_file = nil
    Timeout.timeout(MAX_DOWNLOAD_TIMEOUT) do
      image_file = Down.download(url, max_size: MAX_IMAGE_SIZE)
    end

    return if image_file.nil?

    content_type = image_file.content_type

    # If not an image, send message with format "Title: link"
    if content_type.blank? || !content_type.start_with?('image/')
      Rails.logger.warn "[AttachMessageImageJob] Non-image attachment (#{content_type || 'unknown'}): #{url}"
      send_fallback_message(title, url, message_attrs, message_content)
      return
    end

    # For image files, create attachment
    extension = case content_type
                when 'image/jpeg', 'image/jpg' then '.jpg'
                when 'image/png' then '.png'
                when 'image/gif' then '.gif'
                when 'image/webp' then '.webp'
                else '.jpg'
                end
    filename = "bot_image_#{message_attrs[:conversation_id]}_#{message_attrs[:account_id]}_#{message_attrs[:sender_id]}_#{index}_#{Time.current.to_i}#{extension}"

    message = Message.new(message_attrs.merge(content: title))

    message.attachments.build(
      account_id: message.account_id,
      file_type: 'image',
      file: {
        io: image_file,
        filename: filename,
        content_type: content_type
      }
    )

    message.save!
    Rails.logger.info "[AttachMessageImageJob] Message #{message.id} created with attachment named #{filename}"
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
class Captain::Copilot::AttachMessageImageJob < ApplicationJob
  queue_as :default
  sidekiq_options timeout: 90

  MAX_IMAGE_SIZE = 50 * 1024 * 1024
  MAX_DOWNLOAD_TIMEOUT = 30

  def perform(message_attrs, image_url, index = nil)
    # Rails.logger.info "[AttachMessageImageJob] Downloading image #{index || '?'}: #{image_url}"

    image_file = nil
    Timeout.timeout(MAX_DOWNLOAD_TIMEOUT) do
      image_file = Down.download(image_url, max_size: MAX_IMAGE_SIZE)
    end

    return if image_file.nil?

    content_type = image_file.content_type

    if content_type.blank? || !content_type.start_with?('image/')
      Rails.logger.warn "[AttachMessageImageJob] Skipping non-image attachment (#{content_type || 'unknown'}): #{image_url}"
      return
    end

    extension = case content_type
                when 'image/jpeg', 'image/jpg' then '.jpg'
                when 'image/png' then '.png'
                when 'image/gif' then '.gif'
                when 'image/webp' then '.webp'
                else '.jpg'
                end
    filename = "bot_image_#{message_attrs[:conversation_id]}_#{message_attrs[:account_id]}_#{message_attrs[:sender_id]}_#{index}_#{Time.current.to_i}#{extension}"

    message = Message.new(message_attrs.merge(content: nil))

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
  rescue Timeout::Error => e
    Rails.logger.error "[AttachMessageImageJob] Download timeout for image #{image_url}: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[AttachMessageImageJob] Failed to attach image #{image_url}: #{e.message}"
  end
end
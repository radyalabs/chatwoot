class Captain::Copilot::GreetingImageSender
  MAX_GREETING_IMAGE_SIZE = 10.megabytes

  def initialize(context, log_prefix:)
    @context = context
    @log_prefix = log_prefix
  end

  def perform(caption: nil)
    images = greeting_images
    return false if images.empty?

    Rails.logger.info "#{@log_prefix} sending_greeting_images | conversation_id=#{@context.conversation.id} | image_count=#{images.count}"

    attrs = {
      account_id: @context.account_id,
      inbox_id: @context.conversation.inbox_id,
      conversation_id: @context.conversation.id,
      content_type: 0,
      status: 0,
      message_type: 1,
      sender_type: 'AiAgent',
      sender_id: @context.ai_agent.id
    }

    images.each_with_index do |image_ref, idx|
      image_caption = idx.zero? ? caption : nil
      send_greeting_image(image_ref, attrs, idx, caption: image_caption)
    end

    true
  end

  private

  def greeting_images
    greeting_config = @context.ai_agent.flow_data&.dig('greeting_config') || {}
    images = greeting_config['images'] || []
    images = [greeting_config['image']] if images.empty? && greeting_config['image'].present?
    images
  end

  def send_greeting_image(image_ref, attrs, index, caption: nil)
    return unless image_ref.is_a?(String) && image_ref.present?

    message = Message.new(attrs.merge(content: caption.presence || ''))

    if image_ref.start_with?('data:image/')
      attach_base64_image(message, image_ref, attrs, index)
    else
      attach_signed_id_image(message, image_ref)
    end

    message.save!
    log_greeting_image_sent(index, message.id)
  rescue StandardError => e
    log_greeting_image_send_failed(index, e)
  end

  def attach_base64_image(message, data_url, attrs, index)
    matches = data_url.match(%r{\Adata:(image/\w+);base64,(.+)\z}m)
    return unless matches

    content_type = matches[1]
    decoded = Base64.decode64(matches[2])

    if decoded.bytesize > MAX_GREETING_IMAGE_SIZE
      log_greeting_image_too_large(index, decoded.bytesize)
      return
    end

    ext = { 'image/png' => '.png', 'image/gif' => '.gif', 'image/webp' => '.webp' }.fetch(content_type, '.jpg')
    filename = "greeting_#{attrs[:conversation_id]}_#{index}_#{Time.current.to_i}#{ext}"

    message.attachments.build(
      account_id: attrs[:account_id],
      file_type: 'image',
      file: { io: StringIO.new(decoded), filename: filename, content_type: content_type }
    )
  end

  def attach_signed_id_image(message, signed_id)
    blob = ActiveStorage::Blob.find_signed!(signed_id)

    if blob.byte_size > MAX_GREETING_IMAGE_SIZE
      log_greeting_blob_too_large(blob.byte_size)
      return
    end

    binary_data = blob.download
    io = StringIO.new(binary_data)
    io.binmode

    safe_filename = blob.filename.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '_')

    message.attachments.build(
      account_id: message.account_id,
      file_type: 'image',
      file: {
        io: io,
        filename: safe_filename,
        content_type: blob.content_type.to_s.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
      }
    )
  end

  def log_greeting_image_sent(index, message_id)
    Rails.logger.info(
      "#{@log_prefix} greeting_image_sent | " \
      "conversation_id=#{@context.conversation.id} | " \
      "image_index=#{index + 1} | " \
      "message_id=#{message_id}"
    )
  end

  def log_greeting_image_send_failed(index, error)
    Rails.logger.error(
      "#{@log_prefix} greeting_image_send_failed | " \
      "conversation_id=#{@context.conversation.id} | " \
      "image_index=#{index + 1} | " \
      "error_class=#{error.class.name}"
    )
  end

  def log_greeting_image_too_large(index, image_size)
    Rails.logger.warn(
      "#{@log_prefix} skipped_greeting_image_too_large | " \
      "image_index=#{index + 1} | " \
      "image_size_bytes=#{image_size} | " \
      "max_size_bytes=#{MAX_GREETING_IMAGE_SIZE}"
    )
  end

  def log_greeting_blob_too_large(image_size)
    Rails.logger.warn(
      "#{@log_prefix} skipped_greeting_blob_too_large | " \
      "image_size_bytes=#{image_size} | " \
      "max_size_bytes=#{MAX_GREETING_IMAGE_SIZE}"
    )
  end
end

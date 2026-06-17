class Captain::Copilot::ChatServiceJob < ApplicationJob
  queue_as :send_reply_with_attachments

  BLOB_WAIT_TIMEOUT = 30
  BLOB_CHECK_INTERVAL = 1
  MAX_RETRIES = 3

  retry_on ActiveStorage::FileNotFoundError, wait: 5.seconds, attempts: MAX_RETRIES

  def perform(message_id)
    Rails.logger.info "[ChatServiceJob] >>> START message_id=#{message_id}"
    message = load_message_with_attachments(message_id)
    unless message
      Rails.logger.warn "[ChatServiceJob] Message not found in DB: #{message_id}"
      return
    end

    Rails.logger.info "[ChatServiceJob] Loaded msg_id=#{message_id} conv=#{message.conversation_id} sender=#{message.sender_type}"
    wait_for_attachment_blobs(message)

    Captain::Copilot::ChatService.new(message).perform
  end

  private

  def load_message_with_attachments(message_id)
    Message.includes(attachments: { file_attachment: :blob }).find_by(id: message_id)
  end

  def wait_for_attachment_blobs(message)
    return unless message.attachments.any?

    message.attachments.each do |attachment|
      next unless attachment.file.attached?
      next if attachment.file.blob.blank?

      wait_for_blob(attachment.file.blob, attachment.id)
    end
  end

  def wait_for_blob(blob, attachment_id)
    elapsed = 0

    until blob_exists?(blob)
      if elapsed >= BLOB_WAIT_TIMEOUT
        Rails.logger.error "Attachment #{attachment_id}: Blob #{blob.key} timeout"
        raise ActiveStorage::FileNotFoundError
      end

      Rails.logger.debug { "Attachment #{attachment_id}: waiting for blob #{blob.key}" }
      sleep(BLOB_CHECK_INTERVAL)
      elapsed += BLOB_CHECK_INTERVAL
    end

    Rails.logger.info "Attachment #{attachment_id}: blob #{blob.key} ready after #{elapsed}s"
  end

  def blob_exists?(blob)
    blob.service.exist?(blob.key)
  rescue StandardError => e
    Rails.logger.warn "Error checking blob: #{e.message}"
    false
  end
end

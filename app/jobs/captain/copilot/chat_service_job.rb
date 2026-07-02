class Captain::Copilot::ChatServiceJob < ApplicationJob
  queue_as :send_reply_with_attachments

  BLOB_WAIT_TIMEOUT = 30
  BLOB_CHECK_INTERVAL = 1
  MAX_RETRIES = 3
  ADVISORY_LOCK_NAMESPACE = 10_201

  retry_on ActiveStorage::FileNotFoundError, wait: 5.seconds, attempts: MAX_RETRIES

  def perform(message_id, combined_question: nil, attachments: nil)
    with_message_lock(message_id) do
      message = load_message_with_attachments(message_id)
      return unless message

      if ai_already_replied_after?(message)
        Rails.logger.info("[ChatServiceJob] Skipping duplicate invocation for message #{message.id}")
        return
      end

      wait_for_attachment_blobs(message)

      Captain::Copilot::ChatService.new(
        message,
        combined_question: combined_question,
        attachments: attachments
      ).perform
    end
  rescue StandardError => e
    track_metric('captain.debounce.ai_invocation_failure', message_id: message_id, error: e.class.name)
    raise
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

  def ai_already_replied_after?(message)
    message.conversation.messages
           .where(sender_type: 'AiAgent')
           .exists?([
                      'created_at > ? OR (created_at = ? AND id > ?)',
                      message.created_at,
                      message.created_at,
                      message.id
                    ])
  end

  def with_message_lock(message_id)
    connection = ActiveRecord::Base.connection
    lock_sql = "SELECT pg_advisory_lock(#{ADVISORY_LOCK_NAMESPACE}, #{message_id.to_i})"
    unlock_sql = "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_NAMESPACE}, #{message_id.to_i})"

    connection.execute(lock_sql)
    yield
  ensure
    connection&.execute(unlock_sql)
  end

  def track_metric(event_name, payload)
    ActiveSupport::Notifications.instrument(event_name, payload)
  rescue StandardError => e
    Rails.logger.warn("[ChatServiceJob] metric emit failed: #{e.message}")
  end
end

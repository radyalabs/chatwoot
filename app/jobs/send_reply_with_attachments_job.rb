class SendReplyWithAttachmentsJob < ApplicationJob
  queue_as :critical

  # Maximum time to wait for blob availability (in seconds)
  BLOB_WAIT_TIMEOUT = 120
  # Interval between existence checks (in seconds)
  BLOB_CHECK_INTERVAL = 2

  def perform(message_id)
    message = Message.find(message_id)

    # Wait for all attachment blobs to be accessible in cloud storage
    # This handles Azure's eventual consistency after direct uploads
    wait_for_attachment_blobs(message)

    # Delegate to SendReplyJob's logic to keep DRY
    SendReplyJob.new.perform(message_id)
  end

  private

  def wait_for_attachment_blobs(message)
    message.attachments.each do |attachment|
      next unless attachment.file.attached?

      wait_for_blob(attachment.file.blob, attachment.id)
    end
  end

  def wait_for_blob(blob, attachment_id)
    return if blob.nil?

    elapsed = 0
    until blob_exists?(blob)
      raise_blob_timeout!(blob, attachment_id) if timed_out?(elapsed)

      log_blob_waiting(blob, attachment_id, elapsed)
      elapsed = wait_next_check(elapsed)
    end

    log_blob_available(blob, attachment_id, elapsed)
  end

  def timed_out?(elapsed)
    elapsed >= BLOB_WAIT_TIMEOUT
  end

  def wait_next_check(elapsed)
    sleep(BLOB_CHECK_INTERVAL)
    elapsed + BLOB_CHECK_INTERVAL
  end

  def raise_blob_timeout!(blob, attachment_id)
    Rails.logger.error(
      "[SendReplyWithAttachmentsJob] Timeout waiting for blob #{blob.key} " \
      "(attachment_id: #{attachment_id}) after #{BLOB_WAIT_TIMEOUT}s"
    )
    raise ActiveStorage::FileNotFoundError,
          "Blob #{blob.key} not available after #{BLOB_WAIT_TIMEOUT}s"
  end

  def log_blob_waiting(blob, attachment_id, elapsed)
    Rails.logger.info(
      "[SendReplyWithAttachmentsJob] Waiting for blob #{blob.key} " \
      "(attachment_id: #{attachment_id}), elapsed: #{elapsed}s"
    )
  end

  def log_blob_available(blob, attachment_id, elapsed)
    Rails.logger.info(
      "[SendReplyWithAttachmentsJob] Blob #{blob.key} is now available " \
      "(attachment_id: #{attachment_id}) after #{elapsed}s"
    )
  end

  def blob_exists?(blob)
    blob.service.exist?(blob.key)
  rescue StandardError => e
    Rails.logger.warn(
      "[SendReplyWithAttachmentsJob] Error checking blob existence: #{e.message}"
    )
    false
  end
end

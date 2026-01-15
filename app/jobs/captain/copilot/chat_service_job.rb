class Captain::Copilot::ChatServiceJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return unless message

    # Ensure all attachments are fully uploaded and analyzed before processing
    if message.attachments.any?
      message.attachments.each do |attachment|
        next unless attachment.file.attached?
        
        # Wait for blob to be analyzed
        if attachment.file.blob.present? && !attachment.file.blob.analyzed?
          Rails.logger.info "Analyzing attachment blob #{attachment.file.blob.id} before bot processing..."
          begin
            attachment.file.blob.analyze
          rescue StandardError => e
            Rails.logger.warn "Could not analyze blob: #{e.message}, continuing anyway..."
          end
        end
      end
    end

    Captain::Copilot::ChatService.new(message).perform
  end
end

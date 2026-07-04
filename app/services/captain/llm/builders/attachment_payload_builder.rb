class Captain::Llm::Builders::AttachmentPayloadBuilder
  def initialize(message:, preview_attachments: [])
    @message = message
    @preview_attachments = preview_attachments
  end

  def build
    return @preview_attachments if @preview_attachments.present?

    last_message_attachments.map do |attachment|
      {
        key: attachment.file.key,
        file_type: attachment.file.content_type,
        filename: attachment.file.filename.to_s,
        url: attachment.download_url
      }
    end
  end

  private

  def last_message_attachments
    return [] unless @message.is_a?(Message)

    @message.attachments.includes(file_attachment: :blob).select { |attachment| attachment.file.attached? }
  end
end

class WhatsappUnofficial::SendOnWhatsappUnofficialService < Base::SendOnChannelService
  def channel_class
    Channel::WhatsappUnofficial
  end

  def perform_reply
    begin
      response = channel.send_message(**message_params)
    rescue StandardError => e
      Rails.logger.error "WhatsappUnofficial::SendOnWhatsappUnofficialService: Error sending message to WhatsappUnofficial : #{e.message}"
      message.update!(status: :failed, external_error: e.message)
      return
    end
    message.update!(source_id: response['message_id']) if response.is_a?(Hash) && response['message_id'].present?
  end

  def message_params
    {
      phone_number: contact_inbox.source_id,
      content: message.content,
      attachments: attachments,
      link: link(message)
    }
  end

  def attachments
    message.attachments.filter_map do |attachment|
      next unless attachment.file.attached?

      file_data = attachment.file.download
      file_data.force_encoding('BINARY') if file_data.respond_to?(:force_encoding)

      {
        filename: attachment.file.filename.to_s,
        content_type: attachment.file.content_type,
        io: StringIO.new(file_data),
        file_type: attachment.file_type,
        download_url: attachment.download_url
      }
    end.compact
  end

  def link(message)
    # return message.content_attributes['link'] if message.content_attributes&.dig('link').present?

    return nil if message.content.blank?

    message.content[%r{https?://[^\s]+}]
  end

  def inbox
    @inbox ||= message.inbox
  end

  def channel
    @channel ||= inbox.channel
  end

  def outgoing_message?
    message.outgoing? || message.template?
  end
end

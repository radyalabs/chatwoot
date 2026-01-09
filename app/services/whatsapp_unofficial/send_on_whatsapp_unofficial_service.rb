class WhatsappUnofficial::SendOnWhatsappUnofficialService < Base::SendOnChannelService
  def channel_class
    Channel::WhatsappUnofficial
  end

  def perform_reply
    begin
      response = channel.send_message(**message_params)
    rescue StandardError => e
      message.update!(status: :failed, external_error: e.message)
      return
    end
    message.update!(source_id: response['message_id']) if response.is_a?(Hash) && response['message_id'].present?
  end

  def message_params
    {
      phone_number: contact_inbox.source_id,
      content: message.content,
      attachments: attachments
    }
  end

  def attachments
    message.attachments.filter_map do |attachment|
      next unless attachment.file.attached?

      {
        filename: attachment.file.filename.to_s,
        content_type: attachment.file.content_type,
        io: StringIO.new(attachment.file.download),
        file_type: attachment.file_type,
        download_url: attachment.download_url
      }
    end.compact
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

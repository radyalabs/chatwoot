class WhatsappUnofficial::IncomingMessageService
  include ::FileTypeHelper
  include ::WhatsappUnofficial::IncomingMessageServiceHelpers

  pattr_initialize [:inbox!, :params!]

  def perform
    processed_params
    process_messages
  end

  private

  def process_messages
    set_contact
    return unless @contact

    set_conversation
    create_message
    @message.save!
  end

  def create_message
    @message = @conversation.messages.build(
      content: message_content,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: payload[:id].to_s,
      additional_attributes: additional_attributes
    )

    process_message_attachments if message_params?
  end

  def set_contact
    contact_inbox = ContactInboxWithContactBuilder.new(
      source_id: sender_phone,
      inbox: inbox,
      contact_attributes: contact_attributes
    ).perform

    @contact_inbox = contact_inbox
    @contact = contact_inbox.contact
  end

  def set_conversation
    @conversation = @contact.conversations.where(inbox: inbox).last

    return unless @conversation.blank? || @conversation.resolved?

    @conversation = Conversation.create!(conversation_params)
  end

  def process_message_attachments
    attach_contact
    attach_files
    attach_location
  end

  def attach_files
    return unless file

    file_download_path = file[:media_path]
    if file_download_path.blank?
      Rails.logger.info "Telegram file download path is blank for inbox_id: #{inbox.id}"
      return
    end

    attachment_file = Down.download(
      "#{ENV.fetch('GOWA_API_URL', 'https://gowa.jangkau.ai/')}/#{file_download_path}"
    )

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type,
      file: {
        io: attachment_file,
        filename: attachment_file.original_filename,
        content_type: attachment_file.content_type
      }
    )
  end

  def attach_location
    return unless location

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: :location,
      fallback_title: "#{location[:name]} (#{location[:address]})",
      coordinates_lat: location[:degreesLatitude],
      coordinates_long: location[:degreesLongitude]
    )
  end

  def attach_contact
    return unless contact_card

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: :contact,
      fallback_title: contact_card[:vcard]
    )
  end
end

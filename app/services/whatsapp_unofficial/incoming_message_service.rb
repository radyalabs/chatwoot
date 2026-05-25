class WhatsappUnofficial::IncomingMessageService
  include ::FileTypeHelper
  include ::WhatsappUnofficial::IncomingMessageServiceHelpers

  pattr_initialize [:inbox!, :params!]

  def perform
    processed_params
    set_contact
    set_conversation

    @message = @conversation.messages.build(
      content: message_content,
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      message_type: :incoming,
      sender: @contact,
      source_id: payload[:id].to_s,
      additional_attributes: additional_attributes,
      content_attributes: gowa_reply_content_attributes
    )

    process_message_attachments if message_params?
    @message.save!
  end

  private

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
    return if media_path.blank?

    attachment_file = download_attachment_file
    Rails.logger.info("[ATTACH DEBUG] attachment_file=#{attachment_file.inspect}")
    return if attachment_file.blank?

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
      fallback_title: extract_phone_from_vcard(contact_card[:vcard])
    )
  end

  def process_file(attachment_file)
    if image_file?(attachment_file.content_type)
      compress_image(attachment_file)
    else
      default_file_attributes(attachment_file)
    end
  end

  def compress_image(attachment_file)
    require 'image_processing/mini_magick'

    processed = ImageProcessing::MiniMagick
                .source(attachment_file)
                .resize_to_limit(2000, 2000)
                .strip
                .saver(quality: 85)
                .call

    io = File.open(processed.path, 'rb')
    io.rewind

    {
      io: io,
      filename: attachment_file.original_filename,
      content_type: attachment_file.content_type
    }
  rescue StandardError => e
    Rails.logger.error "Image compression failed: #{e.message}"
    default_file_attributes(attachment_file)
  end

  def default_file_attributes(attachment_file)
    attachment_file.rewind
    {
      io: attachment_file,
      filename: attachment_file.original_filename,
      content_type: attachment_file.content_type
    }
  end

  def image_file?(content_type)
    content_type&.start_with?('image/') && content_type&.exclude?('svg')
  end

  def download_attachment_file
    return if media_path.blank?

    Down.download("#{ENV.fetch('GOWA_API_URL', 'https://gowa.jangkau.ai/')}/#{media_path}")
  end

  def media_path
    return file[:media_path] || file['media_path'] if file.is_a?(Hash)
    return file if file.is_a?(String)

    nil
  end
end

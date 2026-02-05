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
      additional_attributes: additional_attributes
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

  def attach_files # rubocop:disable Metrics/MethodLength
    return unless file

    file_download_path = file[:media_path]
    if file_download_path.blank?
      Rails.logger.info "WhatsApp Go file download path is blank for inbox_id: #{inbox.id}"
      return
    end

    attachment_file = download_file(file_download_path)
    processed_file = process_file(attachment_file)

    @message.attachments.new(
      account_id: @message.account_id,
      file_type: file_content_type,
      file: {
        io: processed_file[:io],
        filename: processed_file[:filename],
        content_type: processed_file[:content_type]
      }
    )
  ensure
    attachment_file&.close
    attachment_file&.unlink if attachment_file.respond_to?(:unlink)
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

    {
      io: File.open(processed.path),
      filename: attachment_file.original_filename,
      content_type: attachment_file.content_type
    }
  rescue StandardError => e
    Rails.logger.error "Image compression failed: #{e.message}"
    default_file_attributes(attachment_file)
  end

  def default_file_attributes(attachment_file)
    {
      io: attachment_file,
      filename: attachment_file.original_filename,
      content_type: attachment_file.content_type
    }
  end

  def image_file?(content_type)
    content_type&.start_with?('image/') && content_type&.exclude?('svg')
  end

  def download_file(file_path)
    Down.download("#{ENV.fetch('GOWA_API_URL', 'https://gowa.jangkau.ai/')}/#{file_path}")
  end
end

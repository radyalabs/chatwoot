module WhatsappUnofficial::IncomingMessageServiceHelpers
  def processed_params
    @processed_params ||= params.deep_symbolize_keys
  end

  def conversation_params
    {
      account_id: @inbox.account_id,
      inbox_id: @inbox.id,
      contact_id: @contact.id,
      contact_inbox_id: @contact_inbox.id
    }
  end

  def additional_attributes
    {
      name: payload[:from_name],
      phone_number: sender_phone,
      channel: 'WhatsappUnofficial'
    }
  end

  def contact_attributes
    {
      name: payload[:from_name],
      phone_number: sender_phone_formatted
    }
  end

  def payload
    @payload ||= processed_params[:payload]
  end

  def message_content
    @message_content ||= if payload[:body].present?
                           payload[:body]
                         elsif payload[:image].present? && payload[:image][:caption].present?
                           payload[:image][:caption]
                         else
                           ''
                         end
  end

  def message_params?
    %i[image document video audio video_note contact location].any? { |type| payload[type].present? }
  end

  def file_content_type
    return :image         if payload[:image].present?
    return :video         if payload[:video].present?
    return :audio         if payload[:audio].present?
    return :file          if payload[:document].present?
  end

  def file
    @file ||= payload[:image].presence ||
              payload[:document].presence ||
              payload[:video].presence ||
              payload[:audio].presence
  end

  def location
    @location ||= payload[:location].presence
  end

  def contact_card
    @contact_card ||= payload[:contact].presence
  end

  def sender_jid
    payload[:from]
  end

  def sender_phone
    sender_jid.split('@').first
  end

  def sender_phone_formatted
    return nil if sender_phone.blank?

    digits_only = sender_phone.gsub(/\D/, '')
    return nil if digits_only.empty?

    "+#{digits_only}"
  end

  def extract_phone_from_vcard(vcard)
    return nil if vcard.blank?

    waid = vcard[/waid=(\d+)/, 1]
    return "+#{waid}" if waid.present?

    tel = vcard[/^TEL.*:(.+)$/, 1]
    return nil if tel.blank?

    digits = tel.gsub(/\D+/, '')
    return nil if digits.blank?

    "+#{digits}"
  end
end

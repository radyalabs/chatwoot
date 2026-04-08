module ChannelMessageSender
  extend ActiveSupport::Concern

  private

  def send_to_channel(inbox, channel_type, receiver_source_id, message_content)
    case channel_type
    when 'whatsapp_unofficial'
      send_whatsapp_unofficial(inbox, receiver_source_id, message_content)
    when 'whatsapp'
      send_whatsapp(inbox, receiver_source_id, message_content)
    when 'telegram'
      send_telegram(inbox, receiver_source_id, message_content)
    when 'instagram'
      send_instagram(inbox, receiver_source_id, message_content)
    else
      raise "Unsupported channel type: #{channel_type}"
    end
  end

  def send_whatsapp_unofficial(inbox, receiver_source_id, message_content)
    channel = inbox.channel
    channel.send_message(
      phone_number: receiver_source_id,
      content: message_content,
      attachments: []
    )
  end

  def send_whatsapp(inbox, receiver_source_id, message_content)
    channel = inbox.channel
    channel.send_message(
      phone_number: receiver_source_id,
      message: message_content
    )
  end

  def send_telegram(inbox, receiver_source_id, message_content)
    channel = inbox.channel
    channel.send_message(chat_id: receiver_source_id, text: message_content)
  end

  def send_instagram(inbox, receiver_source_id, message_content)
    channel = inbox.channel
    channel.send_message(recipient_id: receiver_source_id, message: message_content)
  end

  def validate_inbox_channel(inbox, channel_type)
    expected_class = {
      'whatsapp_unofficial' => 'Channel::WhatsappUnofficial',
      'whatsapp' => 'Channel::Whatsapp',
      'telegram' => 'Channel::Telegram',
      'instagram' => 'Channel::Instagram'
    }[channel_type]

    return if expected_class.nil?
    return if inbox.channel.class.name == expected_class

    raise "Inbox channel type mismatch: expected #{expected_class}, got #{inbox.channel.class.name}"
  end

  def normalize_receiver_source_id(channel_type, receiver_address)
    return nil if receiver_address.blank?

    case channel_type
    when 'whatsapp_unofficial'
      return receiver_address if group_jid?(receiver_address)

      raw = receiver_address.to_s
      raw = raw.split('@').first if raw.include?('@')
      raw.gsub(/\D/, '')
    when 'whatsapp'
      receiver_address.to_s.gsub(/\D/, '')
    else
      receiver_address.to_s
    end
  end

  def group_jid?(whatsapp_address)
    whatsapp_address.to_s.include?('@g.us')
  end
end

module WhatsappUnofficial::IncomingMessageServiceHelpers
  REPLY_ID_CANDIDATE_PATHS = [
    [:replied_to_id],
    [:reply_to_id],
    [:context, :id],
    [:context, :message_id],
    [:context, :messageId],
    [:context, :stanzaId],
    [:context, :stanza_id],

    [:contextInfo, :id],
    [:contextInfo, :message_id],
    [:contextInfo, :messageId],
    [:contextInfo, :stanzaId],
    [:contextInfo, :stanza_id],
    [:contextInfo, :quotedMessageId],
    [:contextInfo, :quoted_message_id],
    [:contextInfo, :quotedMsgId],
    [:contextInfo, :quoted_msg_id],
    [:contextInfo, :quotedStanzaId],
    [:contextInfo, :quoted_stanza_id],

    [:quotedMessageId],
    [:quoted_message_id],
    [:quotedMsgId],
    [:quoted_msg_id],
    [:quotedStanzaId],
    [:quoted_stanza_id],

    [:quoted, :id],
    [:quoted, :message_id],
    [:quoted, :messageId],
    [:quoted, :stanzaId],
    [:quoted, :stanza_id],

    [:message, :contextInfo, :stanzaId],
    [:message, :contextInfo, :stanza_id],
    [:message, :context, :id],

    [:msg, :contextInfo, :stanzaId],
    [:msg, :contextInfo, :stanza_id]
  ].freeze

  REPLY_RELATED_KEYS = %i[
    replied_to_id reply_to_id context contextInfo stanzaId stanza_id quoted quotedMessage quoted_message
    quotedMessageId quoted_message_id quotedMsgId quoted_msg_id quotedStanzaId quoted_stanza_id
    quotedMsgBody quoted_msg_body quotedText quoted_text
  ].freeze

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
                         elsif payload[:image].is_a?(Hash) && payload[:image][:caption].present?
                           payload[:image][:caption]
                         else
                           ''
                         end
  end

  def message_params?
    return true if payload[:image].present?
    %i[image document video audio video_note contact location].any? { |type| payload[type].present? }
  end

  def group_message?
    payload[:chat_id].to_s.end_with?('@g.us')
  end

  def chat_id
    payload[:chat_id]
  end

  def mentioned_jids
    jids = extract_mentioned_jids
    return jids if jids.present?

    extract_mentions_from_body
  end

  def mentioned_bot?(channel)
    return false unless channel

    bot_jid = channel.bot_jid
    bot_phone = channel.phone_number.to_s.gsub(/\D/, '')

    mentioned_jids.any? { |jid| jid.include?(bot_phone) || jid == bot_jid }
  end

  def file_content_type
    return :image         if payload[:sticker].present?
    return :image         if payload[:image].present?
    return :video         if payload[:video].present?
    return :audio         if payload[:audio].present?
    return :file          if payload[:document].present?
  end

  def file
    @file ||= begin
      image = payload[:image]
      if image.is_a?(String)
        { path: image }
      else
        image.presence ||
          payload[:document].presence ||
          payload[:video].presence ||
          payload[:audio].presence ||
          sticker_file
      end
    end
  end

  def sticker_file
    sticker = payload[:sticker]
    return nil unless sticker

    if sticker.is_a?(Hash)
      sticker[:path] || sticker['path'] || sticker[:media_path] || sticker['media_path']
    elsif sticker.is_a?(String)
      sticker
    end
  end

  def message_has_reaction?
    payload[:reaction].present?
  end

  def reaction_data
    return nil unless message_has_reaction?

    reaction = payload[:reaction]
    data = if reaction.is_a?(Hash)
             {
               text: reaction[:text] || reaction['text'],
               message_id: reaction[:message_id] || reaction['message_id'] || reaction[:id] || reaction['id']
             }
           else
             { text: reaction.to_s }
           end

    reacted_id = payload[:reacted_message_id] || payload[:reactedMessageId]
    data[:reacted_message_id] = reacted_id if reacted_id.present?
    data
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

  def gowa_reply_content_attributes
    raw_in_reply_to_external_id = extract_in_reply_to_external_id
    quoted_text = extract_quoted_text
    detected_keys = detect_reply_related_keys

    return {} if raw_in_reply_to_external_id.blank? && quoted_text.blank? && detected_keys.blank?

    maybe_log_gowa_reply_debug(
      raw_in_reply_to_external_id: raw_in_reply_to_external_id,
      quoted_text: quoted_text,
      detected_keys: detected_keys
    )

    attrs = {}
    attrs[:in_reply_to_external_id] = raw_in_reply_to_external_id.to_s if raw_in_reply_to_external_id.present?

    gowa_reply = {}
    gowa_reply[:raw_in_reply_to_external_id] = raw_in_reply_to_external_id.to_s if raw_in_reply_to_external_id.present?
    gowa_reply[:quoted_text] = truncate_text(quoted_text) if quoted_text.present?
    gowa_reply[:detected_keys] = detected_keys if detected_keys.present?
    attrs[:gowa_reply] = gowa_reply if gowa_reply.present?

    attrs
  end

  private

  def extract_mentioned_jids
    direct = dig_any(payload, [
                       [:mentionedJid],
                       [:mentioned_jid],
                       [:mentionedJids],
                       [:mentioned_jids],
                       [:contextInfo, :mentionedJid],
                       [:contextInfo, :mentioned_jid],
                       [:contextInfo, :mentionedJids],
                       [:contextInfo, :mentioned_jids],
                       [:context, :mentionedJid],
                       [:context, :mentioned_jid]
                     ])
    return [] unless direct.is_a?(Array)

    direct.map(&:to_s)
  rescue StandardError
    []
  end

  def extract_mentions_from_body
    body = payload[:body].to_s
    return [] if body.blank?

    body.scan(/@(\d+)/).flatten.map { |phone| "#{phone}@s.whatsapp.net" }
  rescue StandardError
    []
  end

  def extract_in_reply_to_external_id
    candidate = dig_any(payload, REPLY_ID_CANDIDATE_PATHS)
    return candidate if candidate.present?

    deep_find_first_value_by_keys(
      payload,
      %i[stanzaId stanza_id quotedMsgId quoted_msg_id quotedMessageId 
         quoted_message_id quotedStanzaId quoted_stanza_id 
         replied_to_id reply_to_id]
    )
  end

  def extract_quoted_text
    direct = dig_any(payload, [
                       [:quotedMsgBody],
                       [:quoted_msg_body],
                       [:quotedText],
                       [:quoted_text],
                       [:quoted_body],
                       [:quotedBody],
                       [:image, :caption],
                       [:imageMessage, :caption]
                     ])
    return direct if direct.is_a?(String) && direct.present?

    quoted_message_hash = dig_any(payload, [
                              [:contextInfo, :quotedMessage],
                              [:context_info, :quoted_message],
                              [:quotedMessage],
                              [:quoted_message],
                              [:quoted, :quotedMessage],
                              [:quoted, :quoted_message]
                            ])

    extracted = extract_text_from_wa_message_like_hash(quoted_message_hash)
    return extracted if extracted.present?

    nil
  end

  def extract_text_from_wa_message_like_hash(obj)
    return nil unless obj.is_a?(Hash)

    obj[:conversation].presence ||
      obj.dig(:extendedTextMessage, :text).presence ||
      obj.dig(:extended_text_message, :text).presence ||
      obj.dig(:imageMessage, :caption).presence ||
      obj.dig(:image_message, :caption).presence ||
      obj.dig(:videoMessage, :caption).presence ||
      obj.dig(:video_message, :caption).presence ||
      obj.dig(:documentMessage, :caption).presence ||
      obj.dig(:document_message, :caption).presence
  rescue TypeError
    nil
  end

  def detect_reply_related_keys
    deep_find_keys(payload, REPLY_RELATED_KEYS)
  end

  def maybe_log_gowa_reply_debug(raw_in_reply_to_external_id:, quoted_text:, detected_keys:)
    return unless ENV.fetch('GOWA_LOG_REPLY_CONTEXT', nil).present?

    Rails.logger.info(
      {
        tag: 'gowa_reply_context',
        payload_message_id: payload[:id].to_s,
        has_in_reply_to_external_id: raw_in_reply_to_external_id.present?,
        quoted_text_length: quoted_text.is_a?(String) ? quoted_text.length : nil,
        detected_keys: detected_keys,
        payload_top_level_keys: payload.is_a?(Hash) ? payload.keys.first(40) : []
      }.to_json
    )
  rescue StandardError
    nil
  end

  def truncate_text(text, max_length = 500)
    return nil unless text.is_a?(String)

    text.strip.truncate(max_length)
  end

  def dig_any(hash, paths)
    return nil unless hash.is_a?(Hash)

    paths.each do |path|
      value = hash.dig(*path)
      return value if value.respond_to?(:present?) ? value.present? : !value.nil?
    rescue TypeError
      next
    end
    nil
  end

  def deep_find_first_value_by_keys(obj, keys, max_depth: 6)
    return nil if obj.nil?

    keys_set = keys.each_with_object({}) { |k, acc| acc[k] = true }
    queue = [[obj, 0]]

    until queue.empty?
      current, depth = queue.shift
      next if depth > max_depth

      case current
      when Hash
        current.each do |k, v|
          return v if keys_set[k] && (v.is_a?(String) || v.is_a?(Integer)) && v.to_s.present?
          queue << [v, depth + 1]
        end
      when Array
        current.each { |v| queue << [v, depth + 1] }
      end
    end

    nil
  end

  def deep_find_keys(obj, keys, max_depth: 6, limit: 25)
    return [] if obj.nil?

    keys_set = keys.each_with_object({}) { |k, acc| acc[k] = true }
    found = []
    queue = [[obj, 0]]

    until queue.empty?
      current, depth = queue.shift
      next if depth > max_depth

      case current
      when Hash
        current.each do |k, v|
          if keys_set[k] && !found.include?(k)
            found << k
            return found if found.length >= limit
          end
          queue << [v, depth + 1]
        end
      when Array
        current.each { |v| queue << [v, depth + 1] }
      end
    end

    found
  end
end

class Captain::Copilot::GroupContextService
  GROUP_KEYWORDS = %w[
    ringkasan rangkuman summary grup group
    apa.*baru apa.*update happen
  ].freeze

  MAX_GROUPS = 3
  MAX_MESSAGES_PER_GROUP = 25
  MAX_HOURS_LOOKBACK = 48

  def initialize(message, combined_text = nil)
    @message = message
    @combined_text = combined_text
    @conversation = message.conversation
    @inbox = @conversation.inbox
  end

  def group_summary_request?
    check_text.present? && GROUP_KEYWORDS.any? { |kw| check_text.match?(Regexp.new(kw, Regexp::IGNORECASE)) }
  end

  def enrich_message
    return check_text unless group_summary_request?

    group_context = fetch_group_contexts
    return check_text if group_context.blank?

    "#{check_text}\n\n---\nBerikut percakapan terbaru dari grup WhatsApp yang dipantau:\n#{group_context}"
  end

  private

  def check_text
    @combined_text.presence || @message.content.to_s
  end

  def group_conversations
    @inbox.conversations
          .where("additional_attributes->>'group_chat_id' IS NOT NULL")
          .order(updated_at: :desc)
          .limit(MAX_GROUPS)
  end

  def fetch_group_contexts
    group_conversations.filter_map do |conv|
      group_name = conv.additional_attributes&.dig('group_name').presence ||
                   conv.additional_attributes&.dig('group_chat_id')
      messages = recent_messages(conv)
      next if messages.blank?

      msg_texts = messages.map { |msg| format_message(msg) }.join("\n")
      "=== #{group_name} ===\n#{msg_texts}"
    end.join("\n\n")
  end

  def recent_messages(conversation)
    conversation.messages
                .where(message_type: :incoming, private: false)
                .where('created_at > ?', MAX_HOURS_LOOKBACK.hours.ago)
                .order(created_at: :asc)
                .last(MAX_MESSAGES_PER_GROUP)
  end

  def format_message(msg)
    sender = msg.sender&.name || 'Anggota'
    time = msg.created_at.strftime('%H:%M')
    content = msg.content.presence || attachment_summary(msg)
    "[#{time}] #{sender}: #{content.truncate(300)}"
  end

  def attachment_summary(msg)
    types = msg.attachments.map(&:file_type).compact
    return '' if types.blank?
    "[#{types.join(', ')}]"
  end
end

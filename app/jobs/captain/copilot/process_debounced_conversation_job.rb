class Captain::Copilot::ProcessDebouncedConversationJob < ApplicationJob
  queue_as :send_reply_with_attachments

  DEFAULT_MAX_WAIT_SECONDS = 60

  def perform(conversation_id, message_id)
    conversation = Conversation.find_by(id: conversation_id)
    return unless conversation

    state = Captain::Copilot::ConversationAiState.new(conversation)
    latest_message = state.latest_incoming_contact_message
    first_in_burst = state.first_unprocessed_incoming_message
    return unless latest_message && first_in_burst

    return if superseded_schedule?(conversation: conversation, message_id: message_id, latest_message: latest_message, first_in_burst: first_in_burst)

    invoke_chat_service(conversation: conversation, first_in_burst: first_in_burst, latest_message: latest_message)
  end

  private

  def superseded_schedule?(conversation:, message_id:, latest_message:, first_in_burst:)
    scheduled_message = conversation.messages.incoming.find_by(id: message_id, sender_type: 'Contact', private: false)
    return true unless scheduled_message

    return false unless skip_as_superseded?(latest_message: latest_message, scheduled_message: scheduled_message, first_in_burst: first_in_burst)

    track_metric('captain.debounce.noop', conversation_id: conversation.id, message_id: message_id)
    true
  end

  def invoke_chat_service(conversation:, first_in_burst:, latest_message:)
    messages = burst_messages(conversation: conversation, first_in_burst: first_in_burst, latest_message: latest_message)
    return if messages.blank?

    track_metric(
      'captain.debounce.invocation',
      conversation_id: conversation.id,
      message_id: latest_message.id,
      messages_combined: messages.size,
      first_message_wait_seconds: (Time.current - first_in_burst.created_at).to_i
    )

    Captain::Copilot::ChatServiceJob.perform_later(
      latest_message.id,
      combined_question: build_combined_question(messages),
      attachments: collect_attachments(messages)
    )
  end

  def skip_as_superseded?(latest_message:, scheduled_message:, first_in_burst:)
    return false if max_wait_elapsed?(first_in_burst)

    latest_message.id != scheduled_message.id
  end

  def max_wait_elapsed?(first_in_burst)
    (Time.current - first_in_burst.created_at) >= max_wait_seconds
  end

  def max_wait_seconds
    ENV.fetch('CAPTAIN_DEBOUNCE_MAX_WAIT_SECONDS', DEFAULT_MAX_WAIT_SECONDS).to_i
  end

  def burst_messages(conversation:, first_in_burst:, latest_message:)
    conversation.messages.incoming
                .where(sender_type: 'Contact', private: false)
                .where('created_at >= ?', first_in_burst.created_at)
                .where('created_at < ? OR (created_at = ? AND id <= ?)', latest_message.created_at, latest_message.created_at, latest_message.id)
                .includes(attachments: { file_attachment: :blob })
  end

  def build_combined_question(messages)
    return nil if messages.one?

    contents = messages.map { |message| message.content.to_s }
    return nil if contents.all?(&:blank?)

    contents.join("\n")
  end

  def collect_attachments(messages)
    messages.flat_map(&:attachments).select { |att| att.file.attached? }.map do |att|
      {
        key: att.file.key,
        file_type: att.file.content_type,
        filename: att.file.filename.to_s,
        url: att.download_url
      }
    end
  end

  def track_metric(event_name, payload)
    ActiveSupport::Notifications.instrument(event_name, payload)
  rescue StandardError => e
    Rails.logger.warn("[ProcessDebouncedConversationJob] metric emit failed: #{e.message}")
  end
end

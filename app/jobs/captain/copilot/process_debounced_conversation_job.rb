class Captain::Copilot::ProcessDebouncedConversationJob < ApplicationJob
  queue_as :send_reply_with_attachments

  ADVISORY_LOCK_NAMESPACE = 10_202

  def perform(conversation_id, message_id)
    with_conversation_lock(conversation_id) do
      conversation = Conversation.find_by(id: conversation_id)
      return unless conversation

      state = Captain::Copilot::ConversationAiState.new(conversation)
      latest_message = state.latest_incoming_contact_message
      first_in_burst = state.first_unprocessed_incoming_message
      return unless latest_message && first_in_burst

      return if superseded_schedule?(conversation: conversation, message_id: message_id, latest_message: latest_message,
                                     first_in_burst: first_in_burst)

      invoke_chat_service(
        conversation: conversation,
        first_in_burst: first_in_burst,
        latest_message: latest_message,
        processing_boundary_id: state.processing_boundary_message_id
      )
    end
  end

  private

  def superseded_schedule?(conversation:, message_id:, latest_message:, first_in_burst:)
    scheduled_message = conversation.messages.incoming.find_by(id: message_id, sender_type: 'Contact', private: false)
    return true unless scheduled_message

    return false unless skip_as_superseded?(conversation: conversation, latest_message: latest_message,
                                            scheduled_message: scheduled_message, first_in_burst: first_in_burst)

    track_metric('captain.debounce.noop', conversation_id: conversation.id, message_id: message_id)
    true
  end

  def invoke_chat_service(conversation:, first_in_burst:, latest_message:, processing_boundary_id:)
    payload = build_invocation_payload(
      conversation: conversation,
      latest_message: latest_message,
      processing_boundary_id: processing_boundary_id
    )
    return unless payload

    track_invocation_metric(conversation: conversation, latest_message: latest_message, first_in_burst: first_in_burst,
                            messages_size: payload[:messages].size)
    log_invocation(conversation: conversation, latest_message: latest_message, payload: payload)
    enqueue_chat_service(latest_message: latest_message, payload: payload)
    log_watermark_update(conversation: conversation, watermark_before: payload[:watermark_before], latest_message: latest_message)
  end

  def build_invocation_payload(conversation:, latest_message:, processing_boundary_id:)
    messages = burst_messages(conversation: conversation, latest_message: latest_message, processing_boundary_id: processing_boundary_id)
    return if messages.blank?

    {
      messages: messages,
      processing_boundary_id: processing_boundary_id,
      combined_question: build_combined_question(messages),
      attachments: collect_attachments(messages),
      watermark_before: conversation.additional_attributes&.dig('last_debounced_processed_message_id')
    }
  end

  def track_invocation_metric(conversation:, latest_message:, first_in_burst:, messages_size:)
    track_metric(
      'captain.debounce.invocation',
      conversation_id: conversation.id,
      message_id: latest_message.id,
      messages_combined: messages_size,
      first_message_wait_seconds: (Time.current - first_in_burst.created_at).to_i
    )
  end

  def log_invocation(conversation:, latest_message:, payload:)
    Rails.logger.info(
      '[ProcessDebouncedConversationJob] invoking chat service | ' \
      "conversation_id=#{conversation.id} | latest_message_id=#{latest_message.id} | " \
      "processing_boundary_id=#{payload[:processing_boundary_id]} | " \
      "watermark_before=#{payload[:watermark_before]} | " \
      "message_ids=#{payload[:messages].map(&:id)} | messages_combined=#{payload[:messages].size} | " \
      "combined_question_present=#{payload[:combined_question].present?} | " \
      "combined_question=#{payload[:combined_question]&.truncate(500)}"
    )
  end

  def enqueue_chat_service(latest_message:, payload:)
    Captain::Copilot::ChatServiceJob.perform_later(
      latest_message.id,
      combined_question: payload[:combined_question],
      attachments: payload[:attachments]
    )
  end

  def log_watermark_update(conversation:, watermark_before:, latest_message:)
    watermark_after = update_processing_watermark(conversation: conversation, latest_message_id: latest_message.id)
    Rails.logger.info(
      '[ProcessDebouncedConversationJob] updated debounce watermark | ' \
      "conversation_id=#{conversation.id} | watermark_before=#{watermark_before} | " \
      "watermark_after=#{watermark_after}"
    )
  end

  def skip_as_superseded?(conversation:, latest_message:, scheduled_message:, first_in_burst:)
    return false if max_wait_elapsed?(first_in_burst, conversation)

    latest_message.id != scheduled_message.id
  end

  def max_wait_elapsed?(first_in_burst, conversation)
    (Time.current - first_in_burst.created_at) >= max_wait_seconds(conversation)
  end

  def max_wait_seconds(conversation)
    Captain::Copilot::DebounceConfig.for_conversation(conversation).max_wait_seconds
  end

  def burst_messages(conversation:, latest_message:, processing_boundary_id:)
    scope = conversation.messages.incoming
                        .where(sender_type: 'Contact', private: false)
                        .where('id <= ?', latest_message.id)
                        .order(created_at: :asc, id: :asc)
                        .includes(attachments: { file_attachment: :blob })

    return scope unless processing_boundary_id

    scope.where('id > ?', processing_boundary_id)
  end

  def update_processing_watermark(conversation:, latest_message_id:)
    attrs = conversation.additional_attributes.is_a?(Hash) ? conversation.additional_attributes.deep_dup : {}
    watermark_before = attrs['last_debounced_processed_message_id'].to_i
    watermark_after = [watermark_before, latest_message_id.to_i].max
    attrs['last_debounced_processed_message_id'] = watermark_after
    conversation.update!(additional_attributes: attrs)
    watermark_after
  end

  def with_conversation_lock(conversation_id)
    connection = ActiveRecord::Base.connection
    lock_sql = "SELECT pg_advisory_lock(#{ADVISORY_LOCK_NAMESPACE}, #{conversation_id.to_i})"
    unlock_sql = "SELECT pg_advisory_unlock(#{ADVISORY_LOCK_NAMESPACE}, #{conversation_id.to_i})"

    connection.execute(lock_sql)
    yield
  ensure
    connection&.execute(unlock_sql)
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

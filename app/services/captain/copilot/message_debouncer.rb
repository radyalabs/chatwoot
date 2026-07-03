class Captain::Copilot::MessageDebouncer
  def initialize(message)
    @message = message
  end

  def schedule
    Rails.logger.info(
      '[Captain::Copilot::MessageDebouncer] Scheduled debounced processing | ' \
      "conversation_id=#{@message.conversation_id} | message_id=#{@message.id} | " \
      "debounce_interval_seconds=#{debounce_interval_seconds}"
    )

    Captain::Copilot::ProcessDebouncedConversationJob
      .set(wait: debounce_interval_seconds.seconds)
      .perform_later(@message.conversation_id, @message.id)
  end

  private

  def debounce_interval_seconds
    debounce_config.interval_seconds
  end

  def debounce_config
    @debounce_config ||= Captain::Copilot::DebounceConfig.for_message(@message)
  end
end

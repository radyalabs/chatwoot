class Captain::Copilot::MessageDebouncer
  DEFAULT_DEBOUNCE_INTERVAL_SECONDS = 10

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
    ENV.fetch('CAPTAIN_DEBOUNCE_INTERVAL_SECONDS', DEFAULT_DEBOUNCE_INTERVAL_SECONDS).to_i
  end
end

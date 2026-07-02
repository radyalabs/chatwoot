class Captain::Copilot::MessageDebouncer
  DEFAULT_DEBOUNCE_INTERVAL_SECONDS = 10

  def initialize(message)
    @message = message
  end

  def schedule
    Captain::Copilot::ProcessDebouncedConversationJob
      .set(wait: debounce_interval_seconds.seconds)
      .perform_later(@message.conversation_id, @message.id)
  end

  private

  def debounce_interval_seconds
    ENV.fetch('CAPTAIN_DEBOUNCE_INTERVAL_SECONDS', DEFAULT_DEBOUNCE_INTERVAL_SECONDS).to_i
  end
end

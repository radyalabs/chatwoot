class Captain::Llm::JangkauEndpointPolicy
  WELCOME_ENDPOINT = '/v2/chat/welcome/'.freeze
  COMPLETION_ENDPOINT = '/v2/chat/completion/'.freeze

  def initialize(conversation:, ai_agent:)
    @conversation = conversation
    @ai_agent = ai_agent
  end

  def endpoint
    return WELCOME_ENDPOINT if first_message? && welcome_enabled?

    COMPLETION_ENDPOINT
  end

  private

  def first_message?
    !Captain::Copilot::ConversationAiState.new(@conversation).ai_replied?
  end

  def welcome_enabled?
    @ai_agent.display_flow_data&.dig('greeting_config', 'enabled') == true
  end
end

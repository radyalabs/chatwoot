class Captain::Llm::Policies::JangkauEndpointPolicy
  WELCOME_ENDPOINT = '/v2/chat/welcome/'.freeze
  COMPLETION_ENDPOINT = '/v2/chat/completion/'.freeze
  VALID_INTENTS = %i[completion welcome].freeze

  def initialize(intent: :completion)
    @intent = normalize_intent(intent)
  end

  def endpoint
    return WELCOME_ENDPOINT if @intent == :welcome

    COMPLETION_ENDPOINT
  end

  private

  def normalize_intent(intent)
    normalized = intent.to_sym
    return normalized if VALID_INTENTS.include?(normalized)

    raise ArgumentError, "Unsupported Jangkau intent: #{intent}"
  end
end

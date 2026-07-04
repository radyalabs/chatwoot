class Captain::Llm::BaseJangkauService
  LOG_PREFIX = '[Captain::Llm::BaseJangkauService]'.freeze

  def initialize(context:, preview_attachments: [], combined_text: nil, intent: :completion)
    @account_id = context.fetch(:account_id)
    @ai_agent = context.fetch(:ai_agent)
    @conversation = context.fetch(:conversation)
    @message = context.fetch(:message)
    @preview_attachments = preview_attachments
    @combined_text = combined_text
    @intent = intent
  end

  def perform
    generate_response
  end

  private

  def generate_response
    Rails.logger.info "#{LOG_PREFIX} Generating response for Jangkau AI Agent"

    endpoint = endpoint_policy.endpoint
    Rails.logger.info "#{LOG_PREFIX} Using endpoint: #{endpoint}"

    response = api_client.post_with_welcome_fallback(endpoint: endpoint, body: request_body, headers: headers)

    Rails.logger.info "#{LOG_PREFIX} Received Jangkau response"
    response
  rescue StandardError => e
    Rails.logger.error "#{LOG_PREFIX} error_class=#{e.class.name}"
    raise "Failed to generate response: #{e.message}"
  end

  def endpoint_policy
    @endpoint_policy ||= Captain::Llm::Policies::JangkauEndpointPolicy.new(intent: @intent)
  end

  def api_client
    @api_client ||= Captain::Llm::Clients::JangkauApiClient.new
  end

  def request_body
    request_builder.build
  end

  def request_builder
    @request_builder ||= Captain::Llm::Builders::JangkauRequestBuilder.new(
      context: {
        account_id: @account_id,
        ai_agent: @ai_agent,
        conversation: @conversation,
        message: @message
      },
      preview_attachments: @preview_attachments,
      combined_text: @combined_text,
      question_enricher: question_enricher
    )
  end

  def question_enricher
    @question_enricher ||= ->(question) { reply_context_enricher.enrich(question) }
  end

  def reply_context_enricher
    @reply_context_enricher ||= Captain::Llm::WhatsappReplyContextEnricher.new(message: @message)
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-API-Key' => ENV.fetch('JANGKAU_AGENT_API_KEY', nil)
    }
  end
end

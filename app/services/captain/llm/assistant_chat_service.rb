require 'httparty'

class Captain::Llm::AssistantChatService
  include HTTParty

  base_uri ENV.fetch('JANGKAU_AGENT_API_URL', 'https://agent.jangkau.ai/')

  def initialize(context:, attachments: [], intent: :completion)
    @message = context.fetch(:message)
    @conversation = context.fetch(:conversation)
    @ai_agent = context.fetch(:ai_agent)
    @account_id = context.fetch(:account_id)
    @attachments = attachments
    @intent = intent
  end

  def perform
    generate_response
  end

  private

  def generate_response
    return flowise_service.perform if @ai_agent.custom_agent?

    jangkau_service.perform
  end

  def flowise_service
    ::Captain::Llm::BaseFlowiseService.new(
      @account_id,
      @ai_agent,
      @conversation,
      @message
    )
  end

  def jangkau_service
    ::Captain::Llm::BaseJangkauService.new(
      context: {
        account_id: @account_id,
        ai_agent: @ai_agent,
        conversation: @conversation,
        message: @message
      },
      preview_attachments: @attachments,
      intent: @intent
    )
  end
end

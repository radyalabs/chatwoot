require 'httparty'

class Captain::Llm::AssistantChatService
  include HTTParty

  base_uri ENV.fetch('JANGKAU_AGENT_API_URL', 'https://agent.jangkau.ai/')

  def initialize(message, conversation, ai_agent, account_id)
    @message = message
    @conversation = conversation
    @ai_agent = ai_agent
    @account_id = account_id
  end

  def perform
    generate_response
  end

  private

  def generate_response
    if @ai_agent.custom_agent?
      ::Captain::Llm::BaseFlowiseService.new(
        @account_id,
        @ai_agent,
        @conversation,
        @message
      ).perform
    else
      ::Captain::Llm::BaseJangkauService.new(
        @account_id,
        @ai_agent,
        @conversation,
        @message
      ).perform
    end
  end
end

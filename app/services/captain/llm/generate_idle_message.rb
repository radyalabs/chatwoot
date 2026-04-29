class Captain::Llm::GenerateIdleMessage
  include ResponseFormatChatHelper
  include HTTParty
  base_uri ENV.fetch('JANGKAU_AGENT_API_URL', 'https://agent.jangkau.ai/')

  pattr_initialize [:conversation, :step]

  def perform
    raise ArgumentError, 'conversation is nil' if conversation.nil?
    raise ArgumentError, 'agent_bot_inbox not found' if agent_bot_inbox.nil?

    return if ai_agent.nil?

    generate_response
  end

  private

  def generate_response
    Rails.logger.info '[generate_response] Generating response for Jangkau AI Agent'

    endpoint = '/v2/chat/followup/'

    response = self.class.post(
      endpoint,
      body: request_body.to_json,
      headers: headers
    )
    Rails.logger.info '[generate_response] Received Jangkau response'
    parsed = parsed_response(response, is_custom_agent: ai_agent.custom_agent?)
    parsed[:response]
  rescue StandardError => e
    Rails.logger.error "[generate_response] error: #{e.message}"
    raise "Failed to generate response: #{e.message}"
  end

  def agent_bot_inbox
    @agent_bot_inbox ||= AgentBotInbox.find_by(inbox_id: conversation.inbox_id)
  end

  def ai_agent
    return nil if agent_bot_inbox.nil?

    @ai_agent ||= AiAgent.find_by(id: agent_bot_inbox.ai_agent_id)
    Rails.logger.warn "[GenerateIdleMessage] ai_agent not found for ai_agent_id: #{agent_bot_inbox.ai_agent_id}" if @ai_agent.nil?
    @ai_agent
  end

  def request_body
    user_prompt = step.zero? ? user_prompt_initial : user_prompt_closure

    {
      'question' => user_prompt,
      'overrideConfig' => {
        'session_id' => "followup:#{conversation.uuid}",
        'conversation_id' => conversation.id,
        'inbox_id' => conversation.inbox_id,
        'ai_agent_id' => ai_agent.id,
        'vars' => {
          'account_id' => ai_agent.account_id.to_s
        }.merge(ai_agent.flow_data || {})
      }
    }
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-API-Key' => ENV.fetch('JANGKAU_AGENT_API_KEY', nil)
    }
  end

  def user_prompt_initial
    <<~PROMPT
      Analyze the conversation and generate a short, natural follow-up message.
      Keep it low-effort, conversational, and appropriate for the current stage of the chat.
    PROMPT
  end

  def user_prompt_closure
    <<~PROMPT
      Write a short soft closing message acknowledging no reply.
      Limit to 1-2 short sentences.
      Keep the meaning similar to:
      "Alright, since there has been no reply, I will end this chat session for now. Please feel free to contact me again anytime."
    PROMPT
  end
end

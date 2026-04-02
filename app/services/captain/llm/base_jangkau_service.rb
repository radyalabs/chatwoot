require 'httparty'

class Captain::Llm::BaseJangkauService
  include HTTParty
  base_uri ENV.fetch('JANGKAU_AGENT_API_URL', 'https://agent.jangkau.ai/')

  def initialize(account_id, ai_agent, conversation, message)
    @conversation = conversation
    @account_id = account_id
    @ai_agent = ai_agent
    @message = message
    @question, @additional_attributes = extract_message_data
  end

  def perform
    generate_response
  end

  private

  def generate_response
    Rails.logger.info '[generate_response] Generating response for Jangkau AI Agent'

    endpoint = if first_message?(@conversation) && welcome_enabled?(@ai_agent)
                 '/v2/chat/welcome/'
               else
                 '/v2/chat/completion/'
               end

    Rails.logger.info "[generate_response] Using endpoint: #{endpoint}"

    response = self.class.post(
      endpoint,
      body: request_body.to_json,
      headers: headers
    )

    # Fallback: if welcome endpoint fails or returns empty, retry with completion endpoint
    if endpoint == '/v2/chat/welcome/' && (!response.success? || response.parsed_response.blank?)
      Rails.logger.warn "[generate_response] Welcome endpoint failed (#{response.code}), falling back to /v2/chat/completion/"
      response = self.class.post(
        '/v2/chat/completion/',
        body: request_body.to_json,
        headers: headers
      )
    end

    Rails.logger.info '[generate_response] Received Jangkau response'
    response
  rescue StandardError => e
    Rails.logger.error "[generate_response] error: #{e.message}"
    raise "Failed to generate response: #{e.message}"
  end

  def first_message?(conversation)
    conversation.messages.incoming.where(private: false).count == 1
  end

  def welcome_enabled?(ai_agent)
    ai_agent.display_flow_data&.dig('greeting_config', 'enabled') == true
  end

  def request_body
    {
      'question' => @question,
      'attachments' => formatted_attachments,
      'overrideConfig' => override_config
    }.compact
  end

  def formatted_attachments
    last_message_attachments.map do |att|
      {
        key: att.file.key,
        file_type: att.file.content_type,
        filename: att.file.filename.to_s
      }
    end
  end

  def last_message_attachments
    return [] unless @message.is_a?(Message)

    @message.attachments
            .includes(file_attachment: :blob)
            .select { |att| att.file.attached? }
  end

  def override_config
    {
      'session_id' => @conversation.uuid,
      'conversation_id' => @conversation.id,
      'inbox_id' => @conversation.inbox_id,
      'ai_agent_id' => @ai_agent.id,
      'vars' => base_vars.merge(@ai_agent.flow_data || {})
    }
  end

  def base_vars
    {
      'account_id' => @account_id.to_s,
      'customer_name' => @additional_attributes['name'] || '',
      'contact' => @additional_attributes['phone_number'] || '',
      'channel' => @additional_attributes['channel'] || ''
    }
  end

  def extract_message_data
    if @message.is_a?(String)
      [@message, {}]
    else
      # If message has no text content but has attachments, use a placeholder
      question = (@message.content.presence || '')
      [question, @message.additional_attributes || {}]
    end
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-API-Key' => ENV.fetch('JANGKAU_AGENT_API_KEY', nil)
    }
  end
end

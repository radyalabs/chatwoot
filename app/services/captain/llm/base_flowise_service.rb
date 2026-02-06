require 'httparty'

class Captain::Llm::BaseFlowiseService
  include HTTParty
  base_uri ENV.fetch('FLOWISE_API_URL', 'https://ai.radyalabs.id/api/v1')

  def initialize(account_id, ai_agent, conversation, message)
    @account_id = account_id
    @ai_agent = ai_agent
    @conversation = conversation
    @message = message
    @session_id = conversation.uuid
    @question, @additional_attributes = extract_message_data
  end

  def perform
    generate_response
  end

  private

  def generate_response # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    Rails.logger.info '[generate_response] Generating response for Flowise AI Agent'
    response = self.class.post(
      "/prediction/#{@ai_agent.chat_flow_id}",
      body: request_body.to_json,
      headers: headers
    )
    Rails.logger.info '[generate_response] Received Flowise response'
    response
  rescue Net::OpenTimeout => e
    Rails.logger.error "[generate_response] Net::OpenTimeout error: #{e.message}"
    raise "Failed to generate response: #{e.message}"
  rescue Net::ReadTimeout => e
    Rails.logger.error "[generate_response] Net::ReadTimeout error: #{e.message}"
    raise "Failed to generate response: #{e.message}"
  rescue Net::WriteTimeout => e
    Rails.logger.error "[generate_response] Net::WriteTimeout error: #{e.message}"
  rescue HTTParty::Error => e
    Rails.logger.error "[generate_response] HTTParty error: #{e.message}"
    raise "Failed to generate response: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "[generate_response] Standard error: #{e.message}"
    raise "Failed to generate response: #{e.message}"
  end

  def request_body
    {
      'question' => @question,
      'overrideConfig' => {
        'sessionId' => @session_id,
        'vars' => {
          'account_id' => @account_id,
          'table_name' => ENV.fetch('SUPABASE_TABLE_NAME', 'reservasi_klinik')
        }
      }
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
      'Authorization' => "Bearer #{ENV.fetch('FLOWISE_API_KEY', nil)}"
    }
  end
end

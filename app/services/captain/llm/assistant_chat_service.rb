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
    question, additional_attributes = extract_message_data(@message)

    Rails.logger.info "Additional attributes: #{additional_attributes}"

    if @ai_agent.custom_agent?
      ::Captain::Llm::BaseFlowiseService.new(
        @account_id,
        @ai_agent,
        @conversation,
        question,
        additional_attributes
      ).perform
    else
      ::Captain::Llm::BaseJangkauService.new(
        @account_id,
        @ai_agent,
        @conversation,
        question,
        additional_attributes
      ).perform
    end
  end

  def extract_message_data(message)
    if message.is_a?(String)
      [message, {}]
    else
      # If message has no text content but has attachments, use a placeholder
      question = message.content.present? ? message.content : ""
      [question, message.additional_attributes || {}]
    end
  end

  def generate_attachment_placeholder(message)
    # When user sends only attachment without text, provide a meaningful placeholder
    return 'Please analyze the attached image' if message.attachments.any? { |att| att.file_type.to_sym == :image }
    return 'Please analyze the attached audio' if message.attachments.any? { |att| att.file_type.to_sym == :audio }
    return 'Please analyze the attached video' if message.attachments.any? { |att| att.file_type.to_sym == :video }
    return 'Please analyze the attached file' if message.attachments.any? { |att| att.file_type.to_sym == :file }
    
    # Default placeholder
    'Please respond'
  end
end

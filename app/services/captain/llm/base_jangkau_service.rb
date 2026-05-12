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
    Rails.logger.info "[generate_response] request_body=#{request_body.to_json}"

    # endpoint = feature_enabled_for_ai_agent? ? '/v2/chat/completion/' : '/v2/chat/override/'
    endpoint = '/v2/chat/completion/'

    response = self.class.post(
      endpoint,
      body: request_body.to_json,
      headers: headers
    )
    Rails.logger.info '[generate_response] Received Jangkau response'
    response
  rescue StandardError => e
    Rails.logger.error "[generate_response] error: #{e.message}"
    raise "Failed to generate response: #{e.message}"
  end

  def feature_enabled_for_ai_agent?
    enabled_ai_agents = ENV.fetch('FEATURE_FLAG_NEW_JANGKAU_ENDPOINT', '')
                           .split(',')
                           .map(&:strip)

    enabled_ai_agents.include?(@ai_agent.id.to_s)
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
        filename: att.file.filename.to_s,
        url: att.download_url
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
      question = enrich_question_with_reply_context(question)
      [question, @message.additional_attributes || {}]
    end
  end

  def enrich_question_with_reply_context(question)
    return question unless reply_context_enabled?

    replied_text = replied_to_message_text
    return question if replied_text.blank?

    replied_text = replied_text.to_s.strip.truncate(1000)
    question_text = question.to_s

    if question_text.present?
      "User replied to:\n#{replied_text}\n\nUser message:\n#{question_text}"
    else
      "User replied to:\n#{replied_text}"
    end
  rescue StandardError
    question
  end

  def reply_context_enabled?
    return false unless @message.is_a?(Message)

    channel = @message.additional_attributes&.[]('channel') || @message.additional_attributes&.[](:channel)
    return false unless channel.to_s == 'WhatsappUnofficial'

    content_attrs = @message.content_attributes || {}
    in_reply_to = content_attrs[:in_reply_to] || content_attrs['in_reply_to']
    in_reply_to_external_id = content_attrs[:in_reply_to_external_id] ||
                               content_attrs['in_reply_to_external_id'] ||
                               content_attrs.dig('gowa_reply', 'raw_in_reply_to_external_id') ||
                               content_attrs.dig(:gowa_reply, :raw_in_reply_to_external_id)

    in_reply_to.present? || in_reply_to_external_id.present?
  end

  def replied_to_message_text
    return nil unless @message.is_a?(Message)

    content_attrs = @message.content_attributes || {}
    in_reply_to = content_attrs[:in_reply_to] || content_attrs['in_reply_to']
    in_reply_to_external_id = content_attrs[:in_reply_to_external_id] || 
                               content_attrs['in_reply_to_external_id'] ||
                               content_attrs.dig('gowa_reply', 'raw_in_reply_to_external_id') ||
                               content_attrs.dig(:gowa_reply, :raw_in_reply_to_external_id)

    replied_message = if in_reply_to.present?
                        @message.conversation.messages.find_by(id: in_reply_to)
                      elsif in_reply_to_external_id.present?
                        @message.conversation.messages.find_by(source_id: in_reply_to_external_id)
                      end

    # Cek content teks dulu
    return replied_message.content if replied_message&.content.present?

    # Fallback ke attachment jika pesan adalah gambar/file
    if replied_message&.attachments&.any?
      attachment = replied_message.attachments.first
      file_type = attachment.file_type
      return "[User replied to a #{file_type}: #{attachment.file.filename rescue file_type}]"
    end

    # Fallback ke gowa_reply quoted_text
    gowa_reply = content_attrs[:gowa_reply] || content_attrs['gowa_reply']
    return nil unless gowa_reply.is_a?(Hash)

    gowa_reply[:quoted_text] || gowa_reply['quoted_text']
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-API-Key' => ENV.fetch('JANGKAU_AGENT_API_KEY', nil)
    }
  end
end

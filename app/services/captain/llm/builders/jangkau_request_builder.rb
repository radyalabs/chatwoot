class Captain::Llm::Builders::JangkauRequestBuilder
  def initialize(context:, preview_attachments: [], combined_text: nil, question_enricher: nil)
    @account_id = context.fetch(:account_id)
    @ai_agent = context.fetch(:ai_agent)
    @conversation = context.fetch(:conversation)
    @message = context.fetch(:message)
    @preview_attachments = preview_attachments
    @combined_text = combined_text
    @question_enricher = question_enricher
  end

  def build
    question, additional_attributes = extract_message_data

    {
      'question' => question,
      'attachments' => attachment_payload,
      'overrideConfig' => override_config(additional_attributes)
    }.compact
  end

  private

  def extract_message_data
    return [@message, {}] if @message.is_a?(String)

    question = @combined_text.presence || @message.content.presence || ''
    question = enrich_question(question) if @combined_text.blank?

    [question, @message.additional_attributes || {}]
  end

  def enrich_question(question)
    return question unless @question_enricher.respond_to?(:call)

    @question_enricher.call(question)
  end

  def attachment_payload
    @attachment_payload ||= Captain::Llm::Builders::AttachmentPayloadBuilder.new(
      message: @message,
      preview_attachments: @preview_attachments
    ).build
  end

  def override_config(additional_attributes)
    {
      'session_id' => @conversation.uuid,
      'conversation_id' => @conversation.id,
      'inbox_id' => @conversation.inbox_id,
      'ai_agent_id' => @ai_agent.id,
      'vars' => base_vars(additional_attributes).merge(@ai_agent.flow_data || {})
    }
  end

  def base_vars(additional_attributes)
    {
      'account_id' => @account_id.to_s,
      'customer_name' => additional_attributes['name'] || '',
      'contact' => additional_attributes['phone_number'] || '',
      'channel' => additional_attributes['channel'] || ''
    }
  end
end

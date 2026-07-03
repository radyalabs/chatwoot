class Captain::Copilot::ReplyDispatcher
  LOG_PREFIX = '[Captain::Copilot::ReplyDispatcher]'.freeze

  def initialize(context)
    @context = context
  end

  def perform(content:, additional_attributes:)
    attrs, attachments = message_payload(content, additional_attributes)
    Message.create!(attrs)

    enqueue_attachments(attrs, attachments, content)
  end

  private

  def message_payload(content, additional_attributes)
    attributes = additional_attributes || {}
    attachments = attributes.delete(:attachments)

    attrs = base_message_attributes(content)
    attrs.merge!(attributes) if attributes.present?

    [attrs, attachments]
  end

  def base_message_attributes(content)
    {
      content: content,
      account_id: @context.account_id,
      inbox_id: @context.conversation.inbox_id,
      conversation_id: @context.conversation.id,
      content_type: 0,
      status: 0,
      sender_id: @context.ai_agent&.id
    }
  end

  def enqueue_attachments(attrs, attachments, content)
    return if attachments.blank?

    Rails.logger.info "#{LOG_PREFIX} enqueue_async_image_attach | conversation_id=#{@context.conversation.id} | image_count=#{attachments.count}"

    attachments.each_with_index do |attachment, idx|
      Captain::Copilot::AttachMessageImageJob.perform_later(
        attrs,
        attachment,
        idx + 1,
        content
      )
    end
  end
end

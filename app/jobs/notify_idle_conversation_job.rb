class NotifyIdleConversationJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3, timeout: 3600

  STATUS_OPEN = 1
  MESSAGE_TYPE_TEMPLATE = 3
  CONTENT_TYPE_TEXT = 0
  MESSAGE_STATUS_SENT = 0
  DEFAULT_DURATION = ENV.fetch('IDLE_CONVERSATION_DURATION', 5).to_i
  DEFAULT_UNIT = ENV.fetch('IDLE_CONVERSATION_UNIT', 'minutes')

  def perform
    Rails.logger.info('[NotifyIdleConversationJob] Starting processing idle conversations')

    conversations = idle_conversations.includes(:conversation)
    preload_durations(conversations)

    conversations.each do |idle_conversation|
      duration = DEFAULT_DURATION # default duration
      duration = @duration_cache[idle_conversation.ai_agent_id] || DEFAULT_DURATION if idle_conversation.step.positive?

      next unless idle_since?(idle_conversation.conversation.last_activity_at, duration)

      idle_conversation_processor(idle_conversation)
    end

    Rails.logger.info('[NotifyIdleConversationJob] Completed processing idle conversations')
  end

  private

  def preload_durations(conversations)
    ai_agent_ids = conversations.map(&:ai_agent_id).uniq
    @duration_cache = IdleConfig.where(ai_agent_id: ai_agent_ids)
                                .pluck(:ai_agent_id, :duration)
                                .to_h
  end

  def idle_since?(last_activity_at, duration)
    last_activity_at <= duration.send(DEFAULT_UNIT).ago
  end

  def idle_conversation_processor(idle_conversation)
    message = Captain::Llm::GenerateIdleMessage.new(conversation: idle_conversation.conversation).perform

    create_message(
      message, {
        account_id: idle_conversation.account_id,
        inbox_id: idle_conversation.inbox_id,
        conversation_id: idle_conversation.conversation_id
      }
    )

    idle_conversation.mark_as_sent!
  end

  def create_message(message, conversation_attr)
    Message.create!(
      content: message,
      account_id: conversation_attr[:account_id],
      inbox_id: conversation_attr[:inbox_id],
      conversation_id: conversation_attr[:conversation_id],
      message_type: MESSAGE_TYPE_TEMPLATE,
      content_type: CONTENT_TYPE_TEXT,
      status: MESSAGE_STATUS_SENT
    )
  end

  def idle_conversations
    IdleConversation.not_completed.with_conversation_status(:open).with_unassigned_conversation
  end
end

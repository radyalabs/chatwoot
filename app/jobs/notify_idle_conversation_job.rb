class NotifyIdleConversationJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3, timeout: 3600

  STATUS_OPEN = 1
  MESSAGE_TYPE_TEMPLATE = 3
  CONTENT_TYPE_TEXT = 0
  MESSAGE_STATUS_SENT = 0

  def perform
    conversations = idle_conversations.includes(:conversation)
    preload_durations(conversations)

    conversations.each do |idle_conversation|
      duration = @duration_cache[idle_conversation.ai_agent_id] || 30
      next unless idle_since?(idle_conversation.conversation.last_activity_at, duration)

      idle_conversation_processor(idle_conversation)
    end
  end

  private

  def preload_durations(conversations)
    ai_agent_ids = conversations.map(&:ai_agent_id).uniq
    @duration_cache = IdleConfig.where(ai_agent_id: ai_agent_ids)
                                .pluck(:ai_agent_id, :duration)
                                .to_h
  end

  def idle_since?(last_activity_at, duration)
    last_activity_at <= duration.minutes.ago
  end

  def idle_conversation_processor(idle_conversation)
    Rails.logger.info("[NotifyIdleConversationJob] Processing idle conversation ##{idle_conversation.id}")

    Message.create!(
      content: "Test idle conversation notification. [STEP] #{idle_conversation.step + 1}",
      account_id: idle_conversation.account_id,
      inbox_id: idle_conversation.inbox_id,
      conversation_id: idle_conversation.conversation_id,
      message_type: MESSAGE_TYPE_TEMPLATE,
      content_type: CONTENT_TYPE_TEXT,
      status: MESSAGE_STATUS_SENT
    )

    idle_conversation.update!(
      step: idle_conversation.step + 1,
      status: :executing,
      last_sent_at: Time.current
    )
  end

  def idle_conversations
    IdleConversation.with_conversation_status(:open).with_unassigned_conversation
  end
end

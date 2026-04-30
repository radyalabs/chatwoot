class NotifyIdleConversationJob < ApplicationJob
  queue_as :default
  sidekiq_options retry: 3, timeout: 3600

  STATUS_OPEN = 1
  MESSAGE_TYPE_TEMPLATE = 3
  CONTENT_TYPE_TEXT = 0
  MESSAGE_STATUS_SENT = 0
  DEFAULT_DURATION = ENV.fetch('IDLE_CONVERSATION_DURATION', 5).to_i
  DEFAULT_UNIT = ENV.fetch('IDLE_CONVERSATION_UNIT', 'minutes')
  DEFAULT_END_STATE_DURATION = ENV.fetch('DEFAULT_END_STATE_DURATION', 5).to_i
  DEFAULT_END_STATE_UNIT = ENV.fetch('DEFAULT_END_STATE_UNIT', 'minutes')

  def perform
    Rails.logger.info('[NotifyIdleConversationJob] Starting processing idle conversations')

    conversations = idle_conversations.includes(:conversation)
    preload_durations(conversations)

    conversations.each do |idle_conversation|
      duration = DEFAULT_END_STATE_DURATION # default duration
      duration = @duration_cache[idle_conversation.ai_agent_id] || DEFAULT_DURATION if idle_conversation.step.zero?
      unit = idle_conversation.step.zero? ? DEFAULT_UNIT : DEFAULT_END_STATE_UNIT

      next unless idle_since?(idle_conversation.conversation.last_activity_at, duration, unit)

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

  def idle_since?(last_activity_at, duration, unit)
    last_activity_at <= duration.send(unit).ago
  end

  def idle_conversation_processor(idle_conversation)
    handle_orphaned_conversation(idle_conversation) && return if orphaned?(idle_conversation)
    return if (message = generate_message(idle_conversation)).nil?

    create_message(message, conversation_attributes(idle_conversation))
    idle_conversation.mark_as_sent!
    idle_conversation.mark_as_conversation_resolved! if idle_conversation.completed?
  end

  def orphaned?(idle_conversation)
    conversation = idle_conversation.conversation
    inbox = idle_conversation.inbox
    conversation.blank? || inbox.blank?
  rescue ActiveRecord::RecordNotFound
    true
  end

  def handle_orphaned_conversation(idle_conversation)
    log_and_delete(idle_conversation, 'conversation or inbox not found')
    true
  end

  def log_and_delete(idle_conversation, reason)
    Rails.logger.warn "[NotifyIdleConversationJob] Orphaned idle_conversation id:#{idle_conversation.id} - #{reason}, deleting"
    idle_conversation.destroy
    true
  end

  def generate_message(idle_conversation)
    Captain::Llm::GenerateIdleMessage.new(
      conversation: idle_conversation.conversation,
      step: idle_conversation.step
    ).perform
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

  def conversation_attributes(idle_conversation)
    {
      account_id: idle_conversation.account_id,
      inbox_id: idle_conversation.inbox_id,
      conversation_id: idle_conversation.conversation_id
    }
  end

  def idle_conversations
    IdleConversation.not_completed.with_conversation_status(:open).with_unassigned_conversation
  end
end

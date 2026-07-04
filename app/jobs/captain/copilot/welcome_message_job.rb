class Captain::Copilot::WelcomeMessageJob < ApplicationJob
  queue_as :send_reply_with_attachments

  def perform(message_id)
    message = load_message_with_attachments(message_id)
    return unless message

    ai_invocation_lock(message.conversation_id).with_lock do
      Captain::Copilot::WelcomeMessageService.new(message).perform if Captain::Copilot::WelcomeMessagePolicy.new(message).eligible?
    end
  end

  private

  def load_message_with_attachments(message_id)
    Message.includes(attachments: { file_attachment: :blob }).find_by(id: message_id)
  end

  def ai_invocation_lock(conversation_id)
    Captain::Copilot::AiInvocationLock.new(conversation_id)
  end
end

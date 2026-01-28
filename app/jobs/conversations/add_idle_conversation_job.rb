class Conversations::AddIdleConversationJob < ApplicationJob
  queue_as :default

  def perform(ai_response, idle_conversation_params)
    record = IdleConversation.find_or_initialize_by(idle_conversation_params)

    step = determine_step(ai_response)

    record.assign_attributes(
      step: step,
      last_sent_at: Time.current
    )
    record.save!
  end

  private

  def determine_step(ai_response)
    return 2 if ai_response[:is_end_state] && !ai_response[:has_domain_change]
    return 1 if ai_response[:has_domain_change]

    0
  end
end

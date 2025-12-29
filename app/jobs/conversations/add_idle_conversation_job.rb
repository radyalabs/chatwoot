class Conversations::AddIdleConversationJob < ApplicationJob
  queue_as :default

  def perform(ai_response, idle_conversation_params)
    record = IdleConversation.find_or_initialize_by(idle_conversation_params)

    step = determine_step(ai_response)
    status = determine_status(ai_response)

    record.assign_attributes(
      step: step,
      status: step == 2 ? :completed : status,
      last_sent_at: Time.current
    )
    record.save!
  end

  private

  def determine_status(ai_response)
    return :completed if ai_response[:is_end_state] && !ai_response[:is_conversation_success]

    :idle
  end

  def determine_step(ai_response)
    return 2 if ai_response[:is_end_state] && !ai_response[:is_conversation_success]
    return 1 if ai_response[:is_conversation_success]

    0
  end
end

class Captain::Llm::GenerateIdleMessage < Captain::Llm::BaseAzureOpenAiService
  def perform(conversation)
    messages = [
      {
        role: 'system',
        content: system_prompt
      },
      {
        role: 'user',
        content: user_prompt(conversation)
      }
    ]

    response = @client.chat(
      parameters: {
        messages: messages
      }
    )

    response.dig('choices', 0, 'message', 'content')&.strip
  end

  private

  def system_prompt
    <<~PROMPT
      You are a Follow-Up AI Assistant responsible for continuing idle customer conversations based on prior chat context.

      Your task is to generate a single follow-up message that:
      - Naturally references the previous conversation without repeating information
      - Feels polite, friendly, and human
      - Encourages the customer to respond or take the next step
      - Uses concise and conversational language

      Rules:
      - Do NOT restart the conversation or introduce new services
      - Do NOT repeat explanations already given
      - Do NOT sound aggressive, pushy, or overly formal
      - Do NOT mention system data, logs, or that you are an AI

      The message should have one clear intent and feel like a natural continuation of the conversation.
    PROMPT
  end

  def user_prompt(conversation)
    <<~PROMPT
      Generate a polite and engaging follow-up message to re-engage the customer based on the conversation below.

      Conversation Context:
      #{build_conversation_context(conversation)}

      Please provide only the message content without any additional text or formatting.
    PROMPT
  end

  def build_conversation_context(conversation)
    conversation.messages
                .from_ai_or_contact
                .order(created_at: :desc)
                .limit(10)
                .reverse
                .map { |msg| format_message(msg) }
                .join("\n")
  end

  def format_message(message)
    "#{message.sender_type}: #{message.content}"
  end
end

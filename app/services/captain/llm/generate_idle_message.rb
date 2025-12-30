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
      You are an AI assistant that helps to generate a polite and engaging message to re-engage customers in idle conversations. The message should be friendly, concise, and encourage the customer to respond. Avoid using overly formal language or technical jargon. The goal is to make the customer feel valued and prompt them to continue the conversation.
    PROMPT
  end

  def user_prompt(conversation)
    <<~PROMPT
      Generate a polite and engaging message to re-engage a customer in the following conversation:

      Conversation Context:
      #{build_conversation_context(conversation)}

      Please provide only the message content without any additional text or formatting.
    PROMPT
  end

  def build_conversation_context(conversation)
    conversation.messages
                .from_ai_or_contact
                .order(created_at: :desc)
                .limit(5)
                .reverse
                .map { |msg| format_message(msg) }
                .join("\n")
  end

  def format_message(message)
    "#{message.sender_type}: #{message.content}"
  end
end

require 'openai'

class Captain::Llm::ConversationSummaryService < Captain::Llm::BaseAzureOpenAiService
  def initialize(conversation)
    super()
    @conversation = conversation
    @language = conversation.account.locale.presence || 'en'
  end

  def perform
    messages = [system_message, user_message]
    response = @client.chat(parameters: { messages: messages })
    summary = response.dig('choices', 0, 'message', 'content')&.strip
    @conversation.update!(
      ai_summary: summary,
      ai_summary_generated_at: Time.current
    )
    summary
  rescue StandardError => e
    Rails.logger.error("[CAPTAIN][ConversationSummaryService] Error: #{e.message}")
    Rails.logger.error("Error details: #{e.backtrace&.first(5)&.join("\n")}")
    raise
  end

  private

  def system_message
    {
      role: 'system',
      content: <<~PROMPT
        You are a customer service assistant. You MUST write your entire response in #{language_name} only.

        Summarize the bot-customer conversation using EXACTLY these two section headers:

        **#{header_request}**
        [One short paragraph, max 300 characters: what does the customer want?]

        **#{header_followup}**
        [Max 3 bullet points: what could the bot NOT resolve? If all resolved, write a single bullet: "#{none_text}"]

        Only include information explicitly stated in the conversation.
      PROMPT
    }
  end

  def user_message
    {
      role: 'user',
      content: LlmFormatter::LlmTextFormatterService.new(@conversation).format
    }
  end

  def language_name
    case @language
    when 'en' then 'English'
    when 'id' then 'Indonesian (Bahasa Indonesia)'
    else 'English'
    end
  end

  def header_request
    @language == 'id' ? 'Permintaan Klien' : 'Customer Request'
  end

  def header_followup
    @language == 'id' ? 'Perlu Ditindaklanjuti' : 'Follow-up Needed'
  end

  def none_text
    @language == 'id' ? 'Tidak ada' : 'None'
  end
end

require 'openai'

class Captain::Llm::TranslateService < Captain::Llm::BaseAzureOpenAiService
  def initialize(text, target_language = 'en')
    super()
    @text = text
    @target_language = target_language
  end

  def perform
    return @text if @text.blank?

    messages = [system_message, user_message]
    
    response = @client.chat(
      parameters: {
        messages: messages,
        temperature: 0.3
      }
    )

    translated_text = response.dig('choices', 0, 'message', 'content')
    translated_text&.strip || @text
  rescue StandardError => e
    Rails.logger.error("[CAPTAIN][TranslateService] Translation failed: #{e.message}")
    Rails.logger.error("Error details: #{e.backtrace.first(5).join("\n")}")
    @text # Return original text if translation fails
  end

  private

  def system_message
    {
      role: 'system',
      content: "You are a professional translator. Translate the given text to #{language_name}. " \
               "Only return the translated text without any explanation, additional text, or formatting. " \
               "Preserve the original tone and meaning."
    }
  end

  def user_message
    {
      role: 'user',
      content: @text
    }
  end

  def language_name
    case @target_language
    when 'en'
      'English'
    when 'id'
      'Indonesian'
    else
      'English'
    end
  end
end

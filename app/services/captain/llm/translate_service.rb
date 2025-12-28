require 'openai'
require 'json'

class Captain::Llm::TranslateService < Captain::Llm::BaseAzureOpenAiService
  def initialize(json_data, target_language = 'en')
    super()
    @json_data = json_data
    @target_language = target_language
  end

  def perform
    return @json_data if @json_data.blank?

    # Convert to JSON string if it's a hash
    json_string = @json_data.is_a?(String) ? @json_data : @json_data.to_json
    messages = [system_message, user_message(json_string)]
    
    response = @client.chat(
      parameters: {
        messages: messages,
      }
    )

    translated_json = response.dig('choices', 0, 'message', 'content')
    
    # Parse and return as hash
    parsed = JSON.parse(translated_json)
    parsed
  rescue JSON::ParserError => e
    Rails.logger.error("[CAPTAIN][JsonTranslateService] Failed to parse JSON response: #{e.message}")
    @json_data.is_a?(String) ? JSON.parse(@json_data) : @json_data
  rescue StandardError => e
    Rails.logger.error("[CAPTAIN][JsonTranslateService] Translation failed: #{e.message}")
    Rails.logger.error("Error details: #{e.backtrace.first(5).join("\n")}")
    @json_data.is_a?(String) ? JSON.parse(@json_data) : @json_data
  end

  private

  def system_message
    {
      role: 'system',
      content: <<~PROMPT
        You are a professional translator. You will receive a JSON object and must translate ALL string values to #{language_name}.

        ABSOLUTE RULES - DO NOT BREAK:
        1. YOUR ENTIRE RESPONSE MUST BE VALID JSON ONLY - no markdown, code blocks, explanations, or text outside JSON
        2. Keep the EXACT same JSON structure - preserve all keys, nesting, and arrays
        3. Translate ONLY string values - DO NOT translate JSON keys
        4. Preserve all numbers, booleans, null, and arrays as-is
        5. Maintain tone and original meaning of each text
        6. DO NOT add, remove, or rename any fields
        7. Start your response with { and end with } - nothing before or after
        8. Ensure the JSON is parseable - follow this checklist:
           - Escape all quotes inside strings with `\"`
           - Use `\n` for line breaks inside strings
           - No trailing commas
           - All keys use double quotes
           - Only one JSON object/array in the response

        Example:
        Input: {"persona": "Saya \"ramah\" dan sopan\nSiap membantu", "count": 5, "items": ["item1", "item2"]}
        Output: {"persona": "I am \"friendly\" and polite\nReady to help", "count": 5, "items": ["item1", "item2"]}
      PROMPT
    }
  end

  def user_message(json_string)
    {
      role: 'user',
      content: json_string
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

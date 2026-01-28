class Api::V1::Accounts::TranslatorController < Api::V1::Accounts::BaseController
  def translate
    text = params[:text]
    target_language = params[:target_language] || 'en'

    if text.blank?
      return render json: { translated_text: '' }, status: :ok
    end

    translator = Captain::Llm::TranslateService.new(text, target_language)
    translated_text = translator.perform

    render json: { translated_text: translated_text }, status: :ok
  rescue StandardError => e
    Rails.logger.error("[TranslatorController] Translation failed: #{e.message}")
    render json: { error: 'Translation failed', translated_text: text }, status: :unprocessable_entity
  end
end

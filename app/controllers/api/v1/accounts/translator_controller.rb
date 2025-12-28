class Api::V1::Accounts::TranslatorController < Api::V1::Accounts::BaseController
  def translate
    json_data = params[:json_data]
    # Rails.logger.info("[TranslatorController] Received JSON data for translation: #{json_data.inspect}")
    target_language = params[:target_language] || 'en'

    if json_data.blank?
      return render json: { translated_json: {} }, status: :ok
    end

    translator = Captain::Llm::TranslateService.new(json_data, target_language)
    translated_json = translator.perform
    # Rails.logger.info("[TranslatorController] Translated JSON data: #{translated_json.inspect}")

    render json: { translated_json: translated_json }, status: :ok
  rescue StandardError => e
    Rails.logger.error("[TranslatorController] JSON translation failed: #{e.message}")
    # Return original data on error
    original_data = json_data.is_a?(String) ? JSON.parse(json_data) : json_data
    render json: { error: 'Translation failed', translated_json: original_data }, status: :unprocessable_entity
  end
end

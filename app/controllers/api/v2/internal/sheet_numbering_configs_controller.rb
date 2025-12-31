class Api::V2::Internal::SheetNumberingConfigsController < ActionController::API
  before_action :authenticate_api_key!

  # POST /api/v2/internal/sheet_numbering_configs/next_number
  #
  # Atomically generates the next formatted ID and increments counter.
  # Uses pessimistic locking (SELECT FOR UPDATE) to prevent race conditions.
  #
  # Required params:
  #   - account_id: The account ID
  #   - ai_agent_id: The AI agent ID
  #
  # Response (200 OK):
  #   - formatted_id: The generated ID (e.g., "ORN/001/12/2025")
  #   - current_value: The new current_value after increment
  #
  # Response (404 Not Found):
  #   - error: "Sheet numbering config not found"
  #
  # Response (401 Unauthorized):
  #   - error: "Unauthorized"
  #
  def next_number
    Rails.logger.info("[Internal::SheetNumberingConfigs] Generating next number: #{number_params.inspect}")

    result = SheetNumbering::GenerateNextNumberService.new(
      account_id: number_params[:account_id],
      ai_agent_id: number_params[:ai_agent_id]
    ).perform

    Rails.logger.info("[Internal::SheetNumberingConfigs] Generated: #{result[:formatted_id]}, new current_value: #{result[:current_value]}")
    render json: result, status: :ok
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("[Internal::SheetNumberingConfigs] Config not found: #{e.message}")
    render json: { error: 'Sheet numbering config not found' }, status: :not_found
  rescue StandardError => e
    Rails.logger.error("[Internal::SheetNumberingConfigs] Error: #{e.message}")
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  def authenticate_api_key!
    api_key = request.headers['X-Internal-Api-Key'] || params[:api_key]
    expected_key = ENV.fetch('JANGKAU_INTERNAL_API_KEY', nil)

    unless expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key.to_s, expected_key)
      Rails.logger.warn('[Internal::SheetNumberingConfigs] Invalid API key')
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def number_params
    params.permit(:account_id, :ai_agent_id)
  end
end

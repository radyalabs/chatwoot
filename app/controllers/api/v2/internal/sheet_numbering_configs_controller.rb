class Api::V2::Internal::SheetNumberingConfigsController < ActionController::API
  before_action :authenticate_api_key!

  # GET /api/v2/internal/sheet_numbering_configs/config
  #
  # Returns the numbering configuration for a given account, ai_agent, and numbering_key.
  # This endpoint is read-only - counter increment happens in jangkau.langgraph.
  #
  # Required params:
  #   - account_id: The account ID
  #   - ai_agent_id: The AI agent ID
  #   - numbering_key: The numbering key (e.g., "booking", "invoice")
  #
  # Response (200 OK):
  #   {
  #     "id": 1,
  #     "prefix": "ORN/",
  #     "format_pattern": "[NUMBER]/[MONTH]/[YEAR]",
  #     "number_padding": 3,
  #     "numbering_key": "booking"
  #   }
  #
  # Response (404 Not Found):
  #   - error: "Sheet numbering config not found"
  #
  # Response (401 Unauthorized):
  #   - error: "Unauthorized"
  #
  def config
    Rails.logger.info("[Internal::SheetNumberingConfigs] Fetching config: #{config_params.inspect}")

    sheet_config = SheetNumberingConfig.find_by!(
      account_id: config_params[:account_id],
      ai_agent_id: config_params[:ai_agent_id],
      numbering_key: config_params[:numbering_key] || 'default'
    )

    Rails.logger.info("[Internal::SheetNumberingConfigs] Found config id=#{sheet_config.id}")

    render json: {
      id: sheet_config.id,
      prefix: sheet_config.prefix,
      format_pattern: sheet_config.format_pattern,
      number_padding: sheet_config.number_padding,
      numbering_key: sheet_config.numbering_key
    }, status: :ok
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

  def config_params
    params.permit(:account_id, :ai_agent_id, :numbering_key)
  end
end

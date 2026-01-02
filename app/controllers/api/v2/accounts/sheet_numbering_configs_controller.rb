class Api::V2::Accounts::SheetNumberingConfigsController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent
  before_action :set_sheet_numbering_config, only: [:show_config, :update_config]

  # GET /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/sheet_numbering_configs/config
  # Params: numbering_key (optional, defaults to 'default')
  def show_config
    @sheet_numbering_config ||= @ai_agent.sheet_numbering_configs.build(
      account: Current.account,
      numbering_key: numbering_key_param
    )
    render json: sheet_numbering_config_response, status: :ok
  end

  # PUT /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/sheet_numbering_configs/config
  # Params: numbering_key (optional, defaults to 'default')
  def update_config
    @sheet_numbering_config ||= @ai_agent.sheet_numbering_configs.create(
      account: Current.account,
      numbering_key: numbering_key_param
    )

    if @sheet_numbering_config.update(sheet_numbering_config_params)
      render json: sheet_numbering_config_response, status: :ok
    else
      render json: { errors: @sheet_numbering_config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_sheet_numbering_config
    @sheet_numbering_config = @ai_agent.sheet_numbering_configs.find_by(numbering_key: numbering_key_param)
  end

  def numbering_key_param
    params[:numbering_key] || 'default'
  end

  def sheet_numbering_config_response
    {
      id: @sheet_numbering_config.id,
      prefix: @sheet_numbering_config.prefix,
      format_pattern: @sheet_numbering_config.format_pattern,
      current_value: @sheet_numbering_config.current_value,
      number_padding: @sheet_numbering_config.number_padding,
      reset_interval: @sheet_numbering_config.reset_interval,
      numbering_key: @sheet_numbering_config.numbering_key,
      ai_agent_id: @sheet_numbering_config.ai_agent_id,
      account_id: @sheet_numbering_config.account_id,
      created_at: @sheet_numbering_config.created_at,
      updated_at: @sheet_numbering_config.updated_at
    }
  end

  def sheet_numbering_config_params
    params.require(:sheet_numbering_config).permit(
      :prefix,
      :format_pattern,
      :current_value,
      :number_padding,
      :reset_interval,
      :numbering_key
    )
  end
end

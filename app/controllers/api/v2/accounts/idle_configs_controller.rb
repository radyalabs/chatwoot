class Api::V2::Accounts::IdleConfigsController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent
  before_action :set_idle_config, only: [:show_config, :update_config]

  # GET /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/idle_configs/config
  def show_config
    @idle_config ||= @ai_agent.build_idle_config(account: Current.account)
    render json: idle_config_response, status: :ok
  end

  # PUT /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/idle_configs/config
  def update_config
    @idle_config ||= @ai_agent.create_idle_config(account: Current.account)

    if @idle_config.update(idle_config_params)
      render json: idle_config_response, status: :ok
    else
      render json: { errors: @idle_config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_idle_config
    @idle_config = @ai_agent.idle_config
  end

  def idle_config_response
    {
      id: @idle_config.id,
      enabled: @idle_config.enabled,
      duration: @idle_config.duration,
      action: @idle_config.action,
      message: @idle_config.message,
      ai_agent_id: @idle_config.ai_agent_id,
      account_id: @idle_config.account_id,
      created_at: @idle_config.created_at,
      updated_at: @idle_config.updated_at
    }
  end

  def idle_config_params
    params.require(:idle_config).permit(
      :enabled,
      :duration,
      :action,
      :message
    )
  end
end

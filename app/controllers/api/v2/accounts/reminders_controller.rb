class Api::V2::Accounts::RemindersController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent
  before_action :set_reminder_config, only: [:show_config, :update_config]

  # GET /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/reminders/config
  def show_config
    @reminder_config ||= @ai_agent.build_reminder_config(account: Current.account)
    render json: reminder_config_response, status: :ok
  end

  # PUT /api/v2/accounts/:account_id/ai_agents/:ai_agent_id/reminders/config
  def update_config
    @reminder_config ||= @ai_agent.build_reminder_config(account: Current.account)

    if @reminder_config.update(reminder_config_params)
      render json: reminder_config_response, status: :ok
    else
      render json: { errors: @reminder_config.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_reminder_config
    @reminder_config = @ai_agent.reminder_config
  end

  # Explicit response to avoid circular serialization
  def reminder_config_response
    {
      id: @reminder_config.id,
      enabled: @reminder_config.enabled,
      minutes_before_booking: @reminder_config.minutes_before_booking,
      message_template: @reminder_config.message_template,
      ai_agent_id: @reminder_config.ai_agent_id,
      account_id: @reminder_config.account_id,
      created_at: @reminder_config.created_at,
      updated_at: @reminder_config.updated_at
    }
  end

  def reminder_params
    params.require(:reminder).permit(
      :inbox_id,
      :conversation_id,
      :scheduled_at,
      :contact
    )
  end

  def reminder_config_params
    params.require(:reminder_config).permit(
      :enabled,
      :minutes_before_booking,
      :message_template
    )
  end
end

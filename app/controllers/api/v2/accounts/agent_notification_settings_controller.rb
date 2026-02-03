class Api::V2::Accounts::AgentNotificationSettingsController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent
  before_action :set_setting, only: %i[update destroy]

  def index
    @settings = @ai_agent.agent_notification_settings
    render json: @settings.map { |s| setting_response(s) }, status: :ok
  end

  def create
    @setting = @ai_agent.agent_notification_settings.create!(
      permitted_params.merge(account: Current.account)
    )
    render json: setting_response(@setting), status: :created
  end

  def update
    @setting.update!(permitted_params)
    render json: setting_response(@setting), status: :ok
  end

  def destroy
    @setting.destroy!
    head :ok
  end

  private

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_setting
    @setting = @ai_agent.agent_notification_settings.find(params[:id])
  end

  def permitted_params
    params.require(:agent_notification_setting).permit(
      :inbox_id, :category, :interest_level,
      :message_type, :receiver_channel_type,
      :receiver_address, :message_template
    )
  end

  def setting_response(setting)
    {
      id: setting.id,
      inbox_id: setting.inbox_id,
      category: setting.category,
      interest_level: setting.interest_level,
      message_type: setting.message_type,
      receiver_channel_type: setting.receiver_channel_type,
      receiver_address: setting.receiver_address,
      message_template: setting.message_template,
      created_at: setting.created_at,
      updated_at: setting.updated_at
    }
  end
end

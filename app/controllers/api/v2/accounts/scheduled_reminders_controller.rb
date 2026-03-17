class Api::V2::Accounts::ScheduledRemindersController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent
  before_action :set_reminder, only: %i[update destroy]

  def index
    @reminders = @ai_agent.scheduled_reminders.order(created_at: :desc)
    render json: @reminders.map { |r| reminder_response(r) }, status: :ok
  end

  def create
    Current.account.inboxes.find(create_params[:inbox_id])
    @reminder = @ai_agent.scheduled_reminders.create!(
      create_params.merge(account: Current.account)
    )
    render json: reminder_response(@reminder), status: :created
  end

  def update
    if update_params[:inbox_id].present?
      Current.account.inboxes.find(update_params[:inbox_id])
    end
    @reminder.update!(update_params)
    render json: reminder_response(@reminder), status: :ok
  end

  def destroy
    @reminder.destroy!
    head :ok
  end

  private

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  end

  def set_reminder
    @reminder = @ai_agent.scheduled_reminders.find(params[:id])
  end

  def create_params
    parsed = base_params
    parsed[:recurrence_rule] = parse_recurrence_rule if params[:scheduled_reminder][:recurrence_rule].present?
    parsed
  end

  def update_params
    parsed = base_params
    if params[:scheduled_reminder].key?(:recurrence_rule)
      parsed[:recurrence_rule] = params[:scheduled_reminder][:recurrence_rule].present? ? parse_recurrence_rule : nil
    end
    parsed
  end

  def base_params
    params.require(:scheduled_reminder).permit(
      :title, :description, :inbox_id,
      :receiver_channel_type, :message_type,
      :receiver_address, :receiver_name,
      :message_template, :scheduled_at, :timezone,
      :ends_at, :ends_after_count, :enabled
    )
  end

  def parse_recurrence_rule
    rule = params[:scheduled_reminder][:recurrence_rule]
    return nil unless rule.present?
    return rule.to_unsafe_h if rule.respond_to?(:to_unsafe_h)
    return rule if rule.is_a?(Hash)

    JSON.parse(rule)
  rescue JSON::ParserError, TypeError
    render json: { error: 'Invalid recurrence_rule JSON' }, status: :unprocessable_entity
    nil
  end

  def reminder_response(reminder)
    {
      id: reminder.id,
      title: reminder.title,
      description: reminder.description,
      inbox_id: reminder.inbox_id,
      receiver_channel_type: reminder.receiver_channel_type,
      message_type: reminder.message_type,
      receiver_address: reminder.receiver_address,
      receiver_name: reminder.receiver_name,
      message_template: reminder.message_template,
      scheduled_at: reminder.scheduled_at,
      timezone: reminder.timezone,
      recurrence_rule: reminder.recurrence_rule,
      ends_at: reminder.ends_at,
      ends_after_count: reminder.ends_after_count,
      next_occurrence_at: reminder.next_occurrence_at,
      occurrence_count: reminder.occurrence_count,
      last_sent_at: reminder.last_sent_at,
      enabled: reminder.enabled,
      recurrence_summary: reminder.recurrence_summary,
      created_at: reminder.created_at,
      updated_at: reminder.updated_at
    }
  end
end

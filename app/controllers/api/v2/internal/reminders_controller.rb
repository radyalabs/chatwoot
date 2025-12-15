class Api::V2::Internal::RemindersController < ActionController::API
  before_action :authenticate_api_key!

  # POST /api/v2/internal/reminders
  # Creates a reminder from external services (e.g., jangkau.langgraph booking service)
  #
  # Required params:
  #   - account_id: The account ID
  #   - ai_agent_id: The AI agent ID
  #   - conversation_id: The conversation ID (session_id from jangkau maps to this)
  #   - scheduled_at: The scheduled datetime for the reminder
  #
  # Optional params:
  #   - customer_name: Customer's name
  #   - contact: Customer's phone number
  #   - service_type: Type of service (e.g., "Meja restoran")
  #   - service_name: Name of the resource (e.g., "Table 5")
  #   - service_location: Location (e.g., "Cabang Sudirman")
  #
  def create
    Rails.logger.info("[Internal::RemindersController] Creating reminder with params: #{reminder_params.inspect}")

    account = Account.find_by(id: reminder_params[:account_id])
    unless account
      Rails.logger.error("[Internal::RemindersController] Account not found: #{reminder_params[:account_id]}")
      return render json: { error: 'Account not found' }, status: :not_found
    end

    ai_agent = account.ai_agents.find_by(id: reminder_params[:ai_agent_id])
    unless ai_agent
      Rails.logger.error("[Internal::RemindersController] AI Agent not found: #{reminder_params[:ai_agent_id]}")
      return render json: { error: 'AI Agent not found' }, status: :not_found
    end

    # Find conversation by session_id (which is conversation.id in chatwoot)
    conversation = account.conversations.find_by(id: reminder_params[:conversation_id])
    unless conversation
      Rails.logger.error("[Internal::RemindersController] Conversation not found: #{reminder_params[:conversation_id]}")
      return render json: { error: 'Conversation not found' }, status: :not_found
    end

    reminder = Reminder.new(
      account_id: account.id,
      ai_agent_id: ai_agent.id,
      conversation_id: conversation.id,
      inbox_id: conversation.inbox_id,
      scheduled_at: parse_scheduled_at(reminder_params[:scheduled_at]),
      customer_name: reminder_params[:customer_name],
      contact: reminder_params[:contact],
      service_type: reminder_params[:service_type],
      service_name: reminder_params[:service_name],
      service_location: reminder_params[:service_location]
    )

    if reminder.save
      Rails.logger.info("[Internal::RemindersController] Reminder created successfully: id=#{reminder.id}")
      render json: { id: reminder.id, status: 'created' }, status: :created
    else
      Rails.logger.error("[Internal::RemindersController] Failed to create reminder: #{reminder.errors.full_messages}")
      render json: { errors: reminder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_api_key!
    api_key = request.headers['X-Internal-Api-Key'] || params[:api_key]
    expected_key = ENV.fetch('JANGKAU_INTERNAL_API_KEY', nil)

    unless expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key.to_s, expected_key)
      Rails.logger.warn('[Internal::RemindersController] Invalid API key')
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def reminder_params
    params.permit(
      :account_id,
      :ai_agent_id,
      :conversation_id,
      :scheduled_at,
      :customer_name,
      :contact,
      :service_type,
      :service_name,
      :service_location
    )
  end

  def parse_scheduled_at(scheduled_at_str)
    return nil if scheduled_at_str.blank?

    Time.zone.parse(scheduled_at_str)
  rescue ArgumentError => e
    Rails.logger.error("[Internal::RemindersController] Failed to parse scheduled_at: #{e.message}")
    nil
  end
end

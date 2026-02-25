class Api::V2::Internal::ScheduledRemindersController < ActionController::API
  before_action :authenticate_api_key!

  # POST /api/v2/internal/scheduled_reminders
  # Creates a scheduled reminder from external services (e.g., jangkau.langgraph sales agent)
  #
  # Required params:
  #   - account_id: The account ID
  #   - ai_agent_id: The AI agent ID
  #   - inbox_id: The inbox ID
  #   - title: Reminder title
  #   - receiver_address: Recipient phone/address
  #   - message_template: Message content to send
  #   - scheduled_at: First occurrence datetime (ISO 8601)
  #
  # Optional params:
  #   - description: Reminder description/notes
  #   - receiver_name: Recipient name
  #   - receiver_channel_type: Channel type (auto-detected from inbox if omitted)
  #   - message_type: "personal" (default) or "group"
  #   - timezone: Timezone string (default: "Asia/Jakarta")
  #   - recurrence_rule: JSON object with frequency, interval, days_of_week, etc.
  #   - ends_at: Stop sending after this datetime
  #   - ends_after_count: Stop after N occurrences
  #
  def create
    Rails.logger.info("[Internal::ScheduledRemindersController] Creating scheduled reminder with params: #{reminder_params.inspect}")

    account = Account.find_by(id: reminder_params[:account_id])
    unless account
      Rails.logger.error("[Internal::ScheduledRemindersController] Account not found: #{reminder_params[:account_id]}")
      return render json: { error: 'Account not found' }, status: :not_found
    end

    ai_agent = account.ai_agents.find_by(id: reminder_params[:ai_agent_id])
    unless ai_agent
      Rails.logger.error("[Internal::ScheduledRemindersController] AI Agent not found: #{reminder_params[:ai_agent_id]}")
      return render json: { error: 'AI Agent not found' }, status: :not_found
    end

    inbox = account.inboxes.find_by(id: reminder_params[:inbox_id])
    unless inbox
      Rails.logger.error("[Internal::ScheduledRemindersController] Inbox not found: #{reminder_params[:inbox_id]}")
      return render json: { error: 'Inbox not found' }, status: :not_found
    end

    channel_type = reminder_params[:receiver_channel_type] || detect_channel_type(inbox)
    unless channel_type
      return render json: { error: 'Could not determine receiver channel type from inbox' }, status: :unprocessable_entity
    end

    reminder = ai_agent.scheduled_reminders.new(
      account_id: account.id,
      inbox_id: inbox.id,
      title: reminder_params[:title],
      description: reminder_params[:description],
      receiver_address: reminder_params[:receiver_address],
      receiver_name: reminder_params[:receiver_name],
      receiver_channel_type: channel_type,
      message_type: reminder_params[:message_type] || 'personal',
      message_template: reminder_params[:message_template],
      scheduled_at: parse_datetime(reminder_params[:scheduled_at]),
      timezone: reminder_params[:timezone] || 'Asia/Jakarta',
      recurrence_rule: parse_recurrence_rule,
      ends_at: parse_datetime(reminder_params[:ends_at]),
      ends_after_count: reminder_params[:ends_after_count],
      enabled: true
    )

    if reminder.save
      Rails.logger.info("[Internal::ScheduledRemindersController] Scheduled reminder created: id=#{reminder.id}")
      render json: {
        id: reminder.id,
        status: 'created',
        title: reminder.title,
        next_occurrence_at: reminder.next_occurrence_at,
        recurrence_summary: reminder.recurrence_summary
      }, status: :created
    else
      Rails.logger.error("[Internal::ScheduledRemindersController] Failed: #{reminder.errors.full_messages}")
      render json: { errors: reminder.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def authenticate_api_key!
    api_key = request.headers['X-Internal-Api-Key'] || params[:api_key]
    expected_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key.to_s, expected_key)
      Rails.logger.warn('[Internal::ScheduledRemindersController] Invalid API key')
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def reminder_params
    params.permit(
      :account_id, :ai_agent_id, :inbox_id,
      :title, :description,
      :receiver_address, :receiver_name,
      :receiver_channel_type, :message_type,
      :message_template, :scheduled_at, :timezone,
      :ends_at, :ends_after_count,
      recurrence_rule: {}
    )
  end

  def parse_recurrence_rule
    rule = params[:recurrence_rule]
    return nil unless rule.present?
    return rule.to_unsafe_h if rule.respond_to?(:to_unsafe_h)
    return rule if rule.is_a?(Hash)

    JSON.parse(rule)
  rescue JSON::ParserError, TypeError
    nil
  end

  def parse_datetime(datetime_str)
    return nil if datetime_str.blank?

    Time.zone.parse(datetime_str)
  rescue ArgumentError => e
    Rails.logger.error("[Internal::ScheduledRemindersController] Failed to parse datetime: #{e.message}")
    nil
  end

  def detect_channel_type(inbox)
    case inbox.channel.class.name
    when 'Channel::WhatsappUnofficial'
      'whatsapp_unofficial'
    when 'Channel::Whatsapp'
      'whatsapp'
    when 'Channel::Telegram'
      'telegram'
    when 'Channel::Instagram'
      'instagram'
    end
  end
end

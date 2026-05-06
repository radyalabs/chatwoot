class Api::V2::Internal::NotificationsController < ActionController::API
  include ChannelMessageSender

  before_action :authenticate_api_key!

  # POST /api/v2/internal/notifications
  # Payload:
  #   account_id, ai_agent_id, inbox_id, idempotency_key, variables
  def create
    Rails.logger.info('[Internal::Notifications] Received notification dispatch request')

    # # Check idempotency key to prevent duplicate sends on retries
    # if notification_params[:idempotency_key].present?
    #   cache_key = "notification:idempotency:#{notification_params[:idempotency_key]}"
    #   cached_result = ::Redis::Alfred.get(cache_key)
    #   return render json: JSON.parse(cached_result), status: :ok if cached_result.present?
    # end

    account = Account.find_by(id: notification_params[:account_id])
    return render json: { error: 'Account not found' }, status: :not_found unless account

    ai_agent = account.ai_agents.find_by(id: notification_params[:ai_agent_id])
    return render json: { error: 'AI Agent not found' }, status: :not_found unless ai_agent

    settings = find_matching_settings(account, ai_agent)
    return render json: { status: 'skipped', reason: 'no_settings' }, status: :ok if settings.blank?

    results = settings.map { |setting| dispatch_to_setting(account, setting, notification_params) }
    safe_results = results.map { |result| result.is_a?(Hash) ? result : { status: 'failed', error: result.to_s } }

    response_data = {
      status: 'ok',
      sent: safe_results.count { |result| result[:status] == 'sent' },
      failed: safe_results.count { |result| result[:status] == 'failed' },
      results: safe_results
    }

    # # Cache result for idempotency (24 hours)
    # if notification_params[:idempotency_key].present?
    #   cache_key = "notification:idempotency:#{notification_params[:idempotency_key]}"
    #   ::Redis::Alfred.setex(cache_key, response_data.to_json, 24.hours.to_i)
    # end

    render json: response_data, status: :ok
  rescue StandardError => e
    Rails.logger.error("[Internal::Notifications] Failed to dispatch notifications: #{e.message}")
    render json: { error: 'Failed to dispatch notifications' }, status: :unprocessable_entity
  end

  private

  def find_matching_settings(account, ai_agent)
    variables = notification_params[:variables] || {}
    settings = account.agent_notification_settings.where(ai_agent_id: ai_agent.id)

    if variables['category'].present?
      category = variables['category'].to_s.downcase
      settings = settings.where(
        'category IS NULL OR LOWER(category) = ? OR ? = ANY(string_to_array(LOWER(category), \',\'))',
        category, category
      )
    end

    if variables['priority'].present?
      priority = variables['priority'].to_s.downcase
      settings = settings.where('interest_level IS NULL OR LOWER(interest_level) = ?', priority)
    end

    settings
  end

  def authenticate_api_key!
    api_key = request.headers['X-API-Key'] || request.headers['X-Internal-Api-Key'] || params[:api_key]
    expected_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key.to_s, expected_key)
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def notification_params
    params.permit(
      :account_id,
      :ai_agent_id,
      :inbox_id,
      :idempotency_key,
      variables: {}
    )
  end

  def dispatch_to_setting(account, setting, payload)
    inbox = account.inboxes.find_by(id: setting.inbox_id)
    return error_result(setting, 'Sender inbox not found') unless inbox
    return error_result(setting, 'Receiver address is blank') if setting.receiver_address.blank?

    channel_type = setting.receiver_channel_type.to_s

    begin
      validate_inbox_channel(inbox, channel_type)
    rescue StandardError => e
      return error_result(setting, e.message)
    end

    receiver_source_id = normalize_receiver_source_id(channel_type, setting.receiver_address)
    return error_result(setting, 'Receiver source_id missing') if receiver_source_id.blank?

    message_content = render_template(setting.message_template, payload[:variables] || {})

    # Send directly to channel without creating contact/conversation
    send_to_channel(inbox, channel_type, receiver_source_id, message_content)

    { id: setting.id, status: 'sent' }
  rescue ActiveRecord::RecordInvalid => e
    error_result(setting, "Validation failed: #{e.record.errors.full_messages.join(', ')}")
  rescue StandardError => e
    Rails.logger.error("[Internal::Notifications] Failed to send for setting ##{setting.id}: #{e.message}")
    error_result(setting, e.message)
  end

  def error_result(setting, error_message)
    { id: setting.id, status: 'failed', error: error_message }
  end

  def normalize_phone_number_for_contact(channel_type, _receiver_address, receiver_source_id)
    return nil if receiver_source_id.blank?
    return nil unless %w[whatsapp whatsapp_unofficial].include?(channel_type)

    "+#{receiver_source_id}"
  end

  def render_template(template, variables)
    return template if template.blank? || variables.blank?

    variables_hash = variables.to_h
    message = apply_replacements(template, variables_hash)
    append_content(message, variables_hash)
  end

  def apply_replacements(template, variables_hash)
    replacements = build_replacements(variables_hash)
    message = template.dup
    replacements.each { |placeholder, value| message = message.gsub(placeholder, value) }
    message
  end

  def build_replacements(variables_hash)
    replacements = {}

    variables_hash.each { |key, value| replacements["{{#{key}}}"] = value.to_s }

    replacements['{{content_summary}}'] = variables_hash['content_summary'].to_s if variables_hash['content_summary'].present?

    replacements
  end

  def append_content(message, variables_hash)
    return message unless variables_hash['content'].present?

    "#{message}\n\n#{variables_hash['content']}"
  end
end

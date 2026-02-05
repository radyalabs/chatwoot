class Api::V2::Internal::NotificationsController < ActionController::API
  before_action :authenticate_api_key!

  # POST /api/v2/internal/notifications
  # Payload:
  #   account_id, ai_agent_id, inbox_id, category, interest_level, variables
  def create
    Rails.logger.info('[Internal::Notifications] Received notification dispatch request')

    account = Account.find_by(id: notification_params[:account_id])
    return render json: { error: 'Account not found' }, status: :not_found unless account

    ai_agent = account.ai_agents.find_by(id: notification_params[:ai_agent_id])
    return render json: { error: 'AI Agent not found' }, status: :not_found unless ai_agent

    settings = find_matching_settings(account, ai_agent)
    return render json: { status: 'skipped', reason: 'no_settings' }, status: :ok if settings.blank?

    results = settings.map { |setting| dispatch_to_setting(account, setting, notification_params) }
    safe_results = results.map { |result| result.is_a?(Hash) ? result : { status: 'failed', error: result.to_s } }

    render json: {
      status: 'ok',
      sent: safe_results.count { |result| result[:status] == 'sent' },
      failed: safe_results.count { |result| result[:status] == 'failed' },
      results: safe_results
    }, status: :ok
  rescue StandardError => e
    Rails.logger.error("[Internal::Notifications] Failed to dispatch notifications: #{e.message}")
    render json: { error: 'Failed to dispatch notifications' }, status: :unprocessable_entity
  end

  private

  def find_matching_settings(account, ai_agent)
    variables = notification_params[:variables] || {}
    settings = account.agent_notification_settings.where(ai_agent_id: ai_agent.id)

    settings = settings.where(category: variables['category']) if variables['category'].present?
    settings = settings.where('interest_level IS NULL OR interest_level = ?', variables['interest_level']) if variables['interest_level'].present?

    settings
  end

  def authenticate_api_key!
    Rails.logger.info('[Internal::Notifications] Authenticating API key')
    api_key = request.headers['X-API-Key'] || request.headers['X-Internal-Api-Key'] || params[:api_key]
    expected_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless expected_key.present? && ActiveSupport::SecurityUtils.secure_compare(api_key.to_s, expected_key)
      Rails.logger.warn('[Internal::Notifications] Invalid API key')
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end

  def notification_params
    params.permit(
      :account_id,
      :ai_agent_id,
      :inbox_id,
      :category,
      :interest_level,
      variables: {}
    )
  end

  def dispatch_to_setting(account, setting, payload)
    inbox = account.inboxes.find_by(id: setting.inbox_id)
    return error_result(setting, 'Sender inbox not found') unless inbox
    return error_result(setting, 'Receiver address is blank') if setting.receiver_address.blank?

    channel_type = setting.receiver_channel_type.to_s
    validation_error = validate_inbox_channel(inbox, channel_type, setting)
    return validation_error if validation_error

    receiver_source_id = normalize_receiver_source_id(channel_type, setting.receiver_address)
    return error_result(setting, 'Receiver source_id missing') if receiver_source_id.blank?

    message_content = render_template(setting.message_template, payload[:variables] || {})

    contact_inbox = set_contact_inbox(inbox, channel_type, setting.receiver_address, receiver_source_id, payload[:variables] || {})
    conversation = set_conversation(account, inbox, contact_inbox, channel_type, setting.receiver_address)
    create_outgoing_message(account, inbox, conversation, message_content)

    { id: setting.id, status: 'sent', conversation_id: conversation.id }
  rescue ActiveRecord::RecordInvalid => e
    error_result(setting, "Validation failed: #{e.record.errors.full_messages.join(', ')}")
  rescue StandardError => e
    Rails.logger.error("[Internal::Notifications] Failed to send for setting ##{setting.id}: #{e.message}")
    error_result(setting, e.message)
  end

  def set_contact_inbox(inbox, channel_type, receiver_address, receiver_source_id, variables)
    phone_number = normalize_phone_number_for_contact(channel_type, receiver_address, receiver_source_id)
    contact_attrs = build_contact_attributes(channel_type, receiver_address, phone_number, receiver_source_id, variables, inbox)

    ContactInboxWithContactBuilder.new(
      inbox: inbox,
      source_id: receiver_source_id,
      contact_attributes: contact_attrs
    ).perform
  end

  def build_contact_attributes(channel_type, receiver_address, phone_number, receiver_source_id, variables, inbox)
    if channel_type == 'whatsapp_unofficial' && group_jid?(receiver_address)
      group_info = group_info_for_jid(inbox, receiver_address)
      group_name = group_info&.fetch(:name, nil) || receiver_address
      {
        identifier: receiver_address,
        name: group_name,
        additional_attributes: {
          whatsapp_group_jid: receiver_address,
          whatsapp_group_name: group_name
        }
      }
    elsif phone_number.present?
      { phone_number: phone_number, name: receiver_address }
    elsif channel_type == 'telegram'
      {
        name: telegram_contact_name(receiver_address, variables),
        additional_attributes: telegram_contact_attributes(receiver_source_id, variables)
      }
    elsif channel_type == 'instagram'
      {
        name: instagram_contact_name(receiver_address, variables),
        additional_attributes: instagram_contact_attributes(receiver_source_id, variables)
      }
    else
      { identifier: receiver_address, name: receiver_address }
    end
  end

  def set_conversation(account, inbox, contact_inbox, channel_type, receiver_address)
    conversation = Conversation.find_or_create_by!(
      account_id: account.id,
      inbox_id: inbox.id,
      contact_inbox_id: contact_inbox.id
    ) do |conv|
      conv.contact_id = contact_inbox.contact_id
      conv.status = :open
      conv.additional_attributes = conversation_additional_attributes(channel_type, receiver_address)
    end

    ensure_conversation_attributes(conversation, channel_type, receiver_address)
    conversation
  end

  def create_outgoing_message(account, inbox, conversation, message_content)
    Message.create!(
      content: message_content,
      account_id: account.id,
      inbox_id: inbox.id,
      conversation_id: conversation.id,
      message_type: :outgoing,
      content_type: :text,
      status: :sent
    )
  end

  def error_result(setting, error_message)
    { id: setting.id, status: 'failed', error: error_message }
  end

  def validate_inbox_channel(inbox, channel_type, setting)
    case channel_type
    when 'whatsapp_unofficial'
      return error_result(setting, 'Sender inbox channel is not WhatsApp Unofficial') unless inbox.channel.is_a?(Channel::WhatsappUnofficial)
    when 'whatsapp'
      return error_result(setting, 'Sender inbox channel is not WhatsApp') unless inbox.channel.is_a?(Channel::Whatsapp)
    when 'telegram'
      return error_result(setting, 'Sender inbox channel is not Telegram') unless inbox.channel.is_a?(Channel::Telegram)
    when 'instagram'
      return error_result(setting, 'Sender inbox channel is not Instagram') unless inbox.channel.is_a?(Channel::Instagram)
    else
      return error_result(setting, 'Unsupported receiver_channel_type')
    end

    nil
  end

  def telegram_contact_name(receiver_address, variables)
    first_name = variables['first_name'] || variables['telegram_first_name']
    last_name = variables['last_name'] || variables['telegram_last_name']
    full_name = [first_name, last_name].compact.join(' ').strip
    return full_name if full_name.present?

    receiver_address
  end

  def telegram_contact_attributes(receiver_source_id, variables)
    username = variables['username'] || variables['telegram_username'] || variables['social_telegram_user_name']
    language_code = variables['language_code'] || variables['telegram_language_code']

    {
      username: username,
      language_code: language_code,
      social_telegram_user_id: receiver_source_id,
      social_telegram_user_name: username
    }.reject { |_, value| value.nil? }
  end

  def instagram_contact_name(receiver_address, variables)
    variables['instagram_name'] || variables['name'] || receiver_address
  end

  def instagram_contact_attributes(receiver_source_id, variables)
    username = variables['username'] || variables['instagram_username'] || variables['social_instagram_user_name']

    attributes = {
      social_profiles: { instagram: username },
      social_instagram_user_name: username,
      social_instagram_user_id: receiver_source_id
    }

    optional_fields = %w[
      follower_count
      is_user_follow_business
      is_business_follow_user
      is_verified_user
    ]

    optional_fields.each do |field|
      value = variables[field]
      next if value.nil?

      attributes["social_instagram_#{field}"] = value
    end

    attributes.reject { |_, value| value.nil? }
  end

  def group_info_for_jid(inbox, jid)
    return nil unless inbox.channel.respond_to?(:list_groups)

    @group_info_cache ||= {}
    @group_info_cache[inbox.id] ||= begin
      groups = inbox.channel.list_groups
      groups.index_by { |group| group[:jid].to_s }
    end

    @group_info_cache[inbox.id][jid.to_s]
  rescue StandardError => e
    Rails.logger.error("[Internal::Notifications] Failed to fetch group info for #{jid}: #{e.message}")
    nil
  end

  def normalize_receiver_source_id(channel_type, receiver_address)
    return nil if receiver_address.blank?

    case channel_type
    when 'whatsapp_unofficial'
      return receiver_address if group_jid?(receiver_address)

      raw = receiver_address.to_s
      raw = raw.split('@').first if raw.include?('@')
      raw.gsub(/\D/, '')
    when 'whatsapp'
      receiver_address.to_s.gsub(/\D/, '')
    else
      receiver_address.to_s
    end
  end

  def normalize_phone_number_for_contact(channel_type, receiver_address, receiver_source_id)
    return nil if receiver_source_id.blank?
    return nil if channel_type == 'whatsapp_unofficial' && group_jid?(receiver_address)
    return nil unless %w[whatsapp whatsapp_unofficial].include?(channel_type)

    "+#{receiver_source_id}"
  end

  def conversation_additional_attributes(channel_type, receiver_address)
    return { chat_id: receiver_address } if channel_type == 'telegram'

    {}
  end

  def ensure_conversation_attributes(conversation, channel_type, receiver_address)
    attrs = conversation_additional_attributes(channel_type, receiver_address)
    return if attrs.blank?

    existing = conversation.additional_attributes || {}
    normalized_existing = existing.transform_keys(&:to_s)
    normalized_attrs = attrs.transform_keys(&:to_s)
    return if normalized_attrs.all? { |key, value| normalized_existing[key] == value }

    conversation.update!(additional_attributes: normalized_existing.merge(normalized_attrs))
  end

  def group_jid?(whatsapp_address)
    whatsapp_address.to_s.include?('@g.us')
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

    replacements['{{nama_pelanggan}}'] = variables_hash['customer_name'].to_s if variables_hash['customer_name'].present?
    replacements['{{nama_layanan}}'] = variables_hash['product_interest'].to_s if variables_hash['product_interest'].present?
    replacements['{{tingkat_ketertarikan}}'] = variables_hash['classification_interest'].to_s if variables_hash['classification_interest'].present?
    replacements['{{kategori}}'] = variables_hash['category'].to_s if variables_hash['category'].present?

    replacements
  end

  def append_content(message, variables_hash)
    return message unless variables_hash['content'].present?

    "#{message}\n\n#{variables_hash['content']}"
  end
end

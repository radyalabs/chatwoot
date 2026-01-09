# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_whatsapp_unofficials
#
#  id              :bigint           not null, primary key
#  phone_number    :string           not null
#  provider        :string
#  provider_config :jsonb
#  token           :string
#  webhook_url     :string
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  account_id      :integer          not null
#  device_id       :string
#
# Indexes
#
#  index_channel_whatsapp_unofficials_on_account_id    (account_id)
#  index_channel_whatsapp_unofficials_on_phone_number  (phone_number) UNIQUE
#

class Channel::WhatsappUnofficial < ApplicationRecord
  include Channelable
  include WhatsappUnofficial::Cacheable
  include WhatsappUnofficial::PhoneNormalizable

  self.table_name = 'channel_whatsapp_unofficials'

  EDITABLE_ATTRS = [:token, :device_id, :phone_number, :provider, { provider_config: {} }].freeze
  PROVIDERS = %w[waha gowa].freeze

  validates :phone_number, presence: true
  validates :account_id, presence: true
  validates :webhook_url, length: { maximum: Limits::URL_LENGTH_LIMIT }
  validates :provider, inclusion: { in: PROVIDERS }, allow_nil: true

  belongs_to :account
  has_one :inbox, as: :channel, dependent: :destroy

  def name
    'WhatsApp (Unofficial)'
  end

  # Get the adapter for this channel's provider
  def adapter
    @adapter ||= WhatsappUnofficial::AdapterFactory.for(self)
  end

  # Effective provider (with fallback to default)
  def effective_provider
    provider.presence || WhatsappUnofficial::AdapterFactory.default_provider
  end

  # Check if provider is properly configured
  def provider_configured?
    case effective_provider
    when 'waha'
      token.present?
    when 'gowa'
      device_id.present?
    else
      false
    end
  end

  # Delegate QR code retrieval to adapter
  # Returns: { qr_data: String, qr_type: :base64 | :url } or nil
  def qr_code
    adapter.get_qr_code
  end

  # Get QR code with validation (called from controller)
  # rubocop:disable Naming/AccessorMethodName
  def get_qr_code
    Rails.logger.info "Getting QR code for phone #{phone_number}, provider: #{effective_provider}"

    cached_status = read_session_status_from_cache
    if cached_status == 'failed'
      current_attempts = read_mismatch_attempts_from_cache
      error_msg = "Cannot generate QR code - connection failed after #{current_attempts} mismatch attempts."
      Rails.logger.error error_msg
      raise StandardError, error_msg
    end

    # If no credentials, try to create device first
    unless provider_configured?
      Rails.logger.warn "No credentials for #{phone_number}. Attempting to create device..."
      begin
        create_device_with_retry
        reload
        Rails.logger.info 'Device created successfully.'
      rescue StandardError => e
        error_msg = "Failed to create device to get QR code: #{e.message}"
        Rails.logger.error error_msg
        raise StandardError, error_msg
      end
    end

    qr_result = qr_code
    if qr_result
      Rails.logger.info "QR code generated successfully for phone #{phone_number}"
      # Return in format expected by controller
      { 'data' => { 'qr' => qr_result[:qr_data], 'qr_type' => qr_result[:qr_type].to_s } }
    else
      error_msg = 'QR code not available. Make sure device is set up and session is initialized.'
      Rails.logger.error "QR code failed for phone #{phone_number}: #{error_msg}"
      raise StandardError, error_msg
    end
  end
  # rubocop:enable Naming/AccessorMethodName

  # Delegate real-time status check to adapter
  def real_time_status
    Rails.logger.info "Checking real-time status for #{phone_number} from #{effective_provider} API"

    return { 'data' => { 'connected' => false, 'status' => 'not_logged_in' } } unless provider_configured?

    previous_status = read_session_status_from_cache

    begin
      result = adapter.get_session_status
      connected = result[:connected]
      current_status = connected ? 'connected' : 'disconnected'

      if previous_status != current_status
        Rails.logger.info "Status changed for #{phone_number}: #{previous_status} -> #{current_status}"

        if current_status == 'disconnected'
          handle_auto_disconnect
        elsif current_status == 'connected'
          handle_auto_reconnect
        end

        write_session_status_to_cache(current_status)
      end

      {
        'data' => {
          'connected' => connected,
          'status' => connected ? 'logged_in' : 'not_logged_in'
        }
      }
    rescue StandardError => e
      Rails.logger.error "Failed to get real-time status for #{phone_number}: #{e.message}"

      if previous_status == 'connected'
        Rails.logger.warn "API failed, assuming #{phone_number} is disconnected"
        handle_auto_disconnect
        write_session_status_to_cache('disconnected')
      end

      { 'data' => { 'connected' => false, 'status' => 'not_logged_in' } }
    end
  end

  # Set webhook URL based on provider
  def set_webhook_url
    webhook = adapter.webhook_url_for(phone_number)
    update!(webhook_url: webhook)
    Rails.logger.info "Webhook URL set for phone #{phone_number}: #{webhook}"
    webhook
  rescue StandardError => e
    Rails.logger.error "Failed to set webhook URL for phone #{phone_number}: #{e.message}"
    fallback_webhook = "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/webhooks/waha/#{phone_number}"
    update!(webhook_url: fallback_webhook)
    fallback_webhook
  end

  # Create device with retry logic
  def create_device_with_retry(max_retries: 1)
    retries = 0

    begin
      webhook = webhook_url.presence || adapter.webhook_url_for(phone_number)
      update!(webhook_url: webhook) if webhook_url.blank?

      adapter.create_device(webhook_url: webhook)
      adapter.initialize_session
    rescue StandardError => e
      retries += 1
      Rails.logger.error "Attempt #{retries} failed to create device for phone #{phone_number}: #{e.message}"

      if retries < max_retries
        sleep(2**retries)
        retry
      else
        Rails.logger.error "All #{max_retries} attempts failed for phone #{phone_number}"
        raise e
      end
    end
  end

  # Restart session for rescanning QR
  def restart_session_for_rescan
    adapter.restart_session
  end

  # Disconnect/logout session
  def disconnect_waha_session
    adapter.logout_session
  end

  # Delete inbox after failed validation attempts
  def delete_inbox_after_failed_attempts
    Rails.logger.error "Auto-deleting inbox due to failed validation attempts for #{phone_number}"

    begin
      adapter.logout_session if provider_configured?

      clear_session_status_cache
      clear_mismatch_attempts

      if inbox.present?
        inbox_name = inbox.name
        inbox.destroy!
        Rails.logger.info "Inbox '#{inbox_name}' auto-deleted successfully"
        true
      else
        Rails.logger.warn "No inbox found to delete for channel #{phone_number}"
        false
      end
    rescue StandardError => e
      Rails.logger.error "Failed to auto-delete inbox for #{phone_number}: #{e.message}"
      false
    end
  end

  # Handle failed validation attempts
  def handle_failed_validation_attempts
    current_attempts = read_mismatch_attempts_from_cache
    max_attempts = 3

    Rails.logger.info "Checking failed attempts for #{phone_number}: #{current_attempts}/#{max_attempts}"

    if current_attempts >= max_attempts
      Rails.logger.error "Maximum attempts reached for #{phone_number}. Auto-deleting inbox..."

      write_session_status_to_cache('failed', expires_in: 1.hour)
      disconnect_waha_session
      delete_inbox_after_failed_attempts

      {
        success: false,
        auto_deleted: true,
        attempts: current_attempts,
        max_attempts: max_attempts,
        message: "Failed to connect after #{max_attempts} attempts. Inbox has been automatically removed."
      }
    else
      remaining = max_attempts - current_attempts
      {
        success: false,
        auto_deleted: false,
        attempts: current_attempts,
        max_attempts: max_attempts,
        remaining_attempts: remaining,
        message: "Phone number mismatch detected. #{remaining} attempts remaining."
      }
    end
  end

  # Process callback response (used by webhook controllers)
  def process_waha_callback_response(callback_params)
    Rails.logger.info "Processing callback for #{phone_number}"

    event_type = self.class.determine_event_type(callback_params)
    Rails.logger.info "Event type determined: #{event_type}"

    case event_type
    when 'receipt'
      Rails.logger.info 'Receipt callback - updating message status only'
      { type: 'receipt', action: 'update_message_status' }

    when 'message'
      Rails.logger.info 'Regular message callback - no phone validation needed'
      { type: 'regular_message', action: 'process_normally' }

    when 'initial_scan'
      Rails.logger.info 'Initial scan callback detected - validating phone number'
      connected_phone = self.class.extract_phone_from_from_field(callback_params[:from])
      Rails.logger.info "Connected phone from callback: #{connected_phone}, Expected: #{phone_number}"

      validation_result = validate_callback_phone_number(connected_phone)

      if validation_result[:success]
        Rails.logger.info 'Phone validation SUCCESS'
        {
          type: 'initial_scan',
          action: 'validate_success',
          data: {
            session_id: callback_params[:sessionID],
            phone_number: phone_number,
            connected_phone: connected_phone,
            validation_status: 'validated'
          }
        }
      else
        Rails.logger.error 'Phone validation FAILED'
        action = validation_result[:auto_deleted] ? 'validate_failure_auto_deleted' : 'validate_failure'
        {
          type: 'initial_scan',
          action: action,
          data: validation_result.merge(session_id: callback_params[:sessionID])
        }
      end

    else
      Rails.logger.info "Unknown callback type: #{event_type}"
      { type: 'unknown', action: 'process_normally' }
    end
  end

  # Validate callback phone number against expected phone
  def validate_callback_phone_number(callback_phone)
    Rails.logger.info "Validating callback phone: #{callback_phone} against expected: #{phone_number}"

    lock_key = "validation_lock_#{phone_number}"
    lock_value = "#{Time.current.to_f}_#{SecureRandom.hex(4)}"

    is_locked = !::Redis::Alfred.set(lock_key, lock_value, nx: true, ex: 10)

    if is_locked
      handle_validation_lock(lock_key, lock_value)
      return { success: false, status: 'locked', message: 'Validation in progress or duplicate callback' }
    end

    begin
      expected_clean = normalize_phone_number(phone_number)
      callback_clean = normalize_phone_number(self.class.sanitize_phone_number(callback_phone))

      Rails.logger.info "Normalized expected: #{expected_clean}, callback: #{callback_clean}"

      if expected_clean == callback_clean
        Rails.logger.info 'Phone validation SUCCESS - numbers match!'
        clear_mismatch_attempts
        clear_rescan_attempts
        write_session_status_to_cache('validated')

        { success: true, status: 'validated', message: 'Phone number validation successful' }
      else
        handle_phone_mismatch(expected_clean, callback_clean, callback_phone)
      end
    rescue StandardError => e
      Rails.logger.error "Error during validation: #{e.message}"
      { success: false, status: 'error', message: 'Validation error occurred' }
    ensure
      ::Redis::Alfred.delete(lock_key)
      Rails.logger.info "Lock released for #{phone_number}"
    end
  end

  # Legacy method for backward compatibility
  def waha_configured?
    provider_configured?
  end

  # Legacy send message methods (to be implemented by adapters in future)
  def send_message_on_gowa(message)
    message_id = send_message(message) if message.content.present?
    message_id = Waha::SendOnChannelService.new(message: message).perform if message.attachments.present?
    message_id
  end

  def send_message(message)
    # TODO: Implement via adapter
    Rails.logger.warn 'send_message not yet implemented via adapter'
    nil
  end

  private

  def handle_validation_lock(lock_key, lock_value)
    existing_lock_value = ::Redis::Alfred.get(lock_key)
    return unless existing_lock_value

    begin
      lock_time = existing_lock_value.split('_')[0].to_f
      time_held = Time.current.to_f - lock_time

      Rails.logger.info "Lock has been held for #{time_held.round(2)} seconds"

      if time_held > 5.0
        Rails.logger.warn "Breaking stale lock (held for #{time_held.round(2)}s)"
        ::Redis::Alfred.set(lock_key, lock_value, ex: 10) if ::Redis::Alfred.get(lock_key) == existing_lock_value
      end
    rescue StandardError => e
      Rails.logger.error "Error checking lock time: #{e.message}"
    end
  end

  def handle_phone_mismatch(expected_clean, callback_clean, callback_phone)
    Rails.logger.error "Phone validation FAILED - Expected: #{expected_clean}, Got: #{callback_clean}"

    current_rescan_attempts = read_rescan_attempts_from_cache
    is_rescan = current_rescan_attempts > 0
    current_attempts = increment_mismatch_attempts
    max_attempts = 3

    context = is_rescan ? 'rescan' : 'initial scan'
    Rails.logger.error "#{context.capitalize} mismatch attempt #{current_attempts}/#{max_attempts}"

    if current_attempts >= max_attempts
      Rails.logger.error "Maximum mismatch attempts (#{max_attempts}) reached for #{phone_number}"
      write_session_status_to_cache('failed', expires_in: 1.hour)
      disconnect_waha_session
      broadcast_session_failed(callback_phone, current_attempts)

      {
        success: false,
        status: 'failed',
        attempts: current_attempts,
        max_attempts: max_attempts,
        auto_deleted: true,
        message: "Phone number validation failed after #{max_attempts} attempts.",
        rescan_context: is_rescan
      }
    else
      write_session_status_to_cache('mismatch', expires_in: 10.minutes)
      disconnect_waha_session
      broadcast_session_mismatch(callback_phone, current_attempts, max_attempts)

      {
        success: false,
        status: 'mismatch',
        attempts: current_attempts,
        max_attempts: max_attempts,
        message: 'Phone number mismatch - session logged out',
        expected_phone: expected_clean,
        connected_phone: callback_clean,
        rescan_context: is_rescan
      }
    end
  end

  def handle_auto_disconnect
    Rails.logger.warn "Auto-detected disconnect for #{phone_number}"
    clear_mismatch_attempts
    broadcast_disconnect_event
  end

  def handle_auto_reconnect
    Rails.logger.info "Auto-detected reconnect for #{phone_number}"
    clear_mismatch_attempts
    broadcast_reconnect_event
  end

  def broadcast_disconnect_event
    return unless inbox.present?

    broadcast_status_event('auto_disconnect', 'disconnected', false)
  end

  def broadcast_reconnect_event
    return unless inbox.present?

    broadcast_status_event('auto_reconnect', 'connected', true)
  end

  def broadcast_session_mismatch(callback_phone, current_attempts, max_attempts)
    return unless inbox.present?

    controller = Waha::CallbackController.new
    controller.send(:broadcast_session_mismatch, self, callback_phone, current_attempts, max_attempts)
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast session mismatch: #{e.message}"
  end

  def broadcast_session_failed(callback_phone, current_attempts)
    return unless inbox.present?

    controller = Waha::CallbackController.new
    controller.send(:broadcast_session_failed, self, callback_phone, current_attempts)
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast session failed: #{e.message}"
  end

  def broadcast_status_event(event_type, status, connected)
    inbox_pubsub_token = "#{account_id}_inbox_#{inbox.id}"

    broadcast_data = {
      event: 'whatsapp_status_changed',
      type: event_type,
      status: status,
      connected: connected,
      phone_number: phone_number,
      inbox_id: inbox.id,
      account_id: account_id,
      timestamp: Time.current.iso8601
    }

    Rails.logger.info "Broadcasting #{event_type} for #{phone_number}"

    ActionCable.server.broadcast(inbox_pubsub_token, broadcast_data)

    account.users.each do |user|
      ActionCable.server.broadcast(user.pubsub_token, broadcast_data)
    end

    Rails.logger.info "#{event_type.titleize} event broadcasted successfully"
  rescue StandardError => e
    Rails.logger.error "Failed to broadcast #{event_type} event: #{e.message}"
  end
end

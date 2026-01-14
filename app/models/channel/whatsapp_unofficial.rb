# frozen_string_literal: true

# == Schema Information
#
# Table name: channel_whatsapp_unofficials
#
#  id              :bigint           not null, primary key
#  phone_number    :string           not null
#  provider        :string
#  provider_config :jsonb
#  status          :string           default("disconnected"), not null
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
#  index_channel_whatsapp_unofficials_on_status        (status)
#

class Channel::WhatsappUnofficial < ApplicationRecord
  include Channelable
  include WhatsappUnofficial::Cacheable
  include WhatsappUnofficial::PhoneNormalizable

  self.table_name = 'channel_whatsapp_unofficials'

  EDITABLE_ATTRS = [:token, :device_id, :phone_number, :provider, { provider_config: {} }].freeze
  PROVIDERS = %w[waha gowa].freeze

  # Connection status values stored in the database
  # These represent the user-facing connection state
  STATUS_CONNECTED = 'connected'
  STATUS_DISCONNECTED = 'disconnected'
  STATUS_WAITING = 'waiting' # Waiting for QR scan
  STATUSES = [STATUS_CONNECTED, STATUS_DISCONNECTED, STATUS_WAITING].freeze

  validates :phone_number, presence: true
  validates :account_id, presence: true
  validates :webhook_url, length: { maximum: Limits::URL_LENGTH_LIMIT }
  validates :provider, inclusion: { in: PROVIDERS }, allow_nil: true
  validates :status, inclusion: { in: STATUSES }

  belongs_to :account
  has_one :inbox, as: :channel, dependent: :destroy

  before_destroy :cleanup_provider_device

  # ============================================================================
  # Core Identity
  # ============================================================================

  def name
    'WhatsApp (Unofficial)'
  end

  def provider_service
    if provider == 'gowa'
      WhatsappUnofficial::Providers::GowaService.new(whatsapp_channel: self)
    elsif provider == 'wapi'
      WhatsappUnofficial::Providers::WapiService.new(whatsapp_channel: self)
    end
  end

  delegate :send_message, to: :provider_service

  def clear_session_status_cache
    ::Redis::Alfred.delete(session_status_cache_key)
  end

  # Get the adapter for this channel's provider
  def adapter
    @adapter ||= WhatsappUnofficial::AdapterFactory.for(self)
  end

  def effective_provider
    provider.presence || WhatsappUnofficial::AdapterFactory.default_provider
  end

  def provider_configured?
    case effective_provider
    when 'waha' then token.present?
    when 'gowa' then device_id.present?
    else false
    end
  end

  # Legacy alias for backward compatibility
  alias waha_configured? provider_configured?

  # ============================================================================
  # Connection Status Management
  # ============================================================================

  # Check if the channel is currently connected
  def connected?
    status == STATUS_CONNECTED
  end

  # Check if the channel is disconnected (user/admin initiated or device not found)
  # When true, session status checks should be skipped
  def disconnected?
    status == STATUS_DISCONNECTED
  end

  # Check if the channel is waiting for QR scan
  def waiting_for_qr?
    status == STATUS_WAITING
  end

  # Update status to connected
  def mark_as_connected!
    update!(status: STATUS_CONNECTED)
    Rails.logger.info "Channel #{phone_number} marked as connected"
  end

  # Update status to disconnected (user/admin initiated)
  def mark_as_disconnected!
    update!(status: STATUS_DISCONNECTED)
    Rails.logger.info "Channel #{phone_number} marked as disconnected"
  end

  # Update status to waiting for QR scan
  def mark_as_waiting!
    update!(status: STATUS_WAITING)
    Rails.logger.info "Channel #{phone_number} marked as waiting for QR"
  end

  # ============================================================================
  # Service Delegations
  # ============================================================================

  # Get QR code with validation (called from controller)
  # Delegates to QrCodeService
  # rubocop:disable Naming/AccessorMethodName
  def get_qr_code
    WhatsappUnofficial::QrCodeService.new(self).perform
  end
  # rubocop:enable Naming/AccessorMethodName

  # Check real-time session status from provider API
  # Delegates to SessionStatusService
  def real_time_status
    WhatsappUnofficial::SessionStatusService.new(self).perform
  end

  # Process callback response (used by webhook controllers)
  # Delegates to CallbackProcessor
  def process_waha_callback_response(callback_params)
    WhatsappUnofficial::CallbackProcessor.new(self, callback_params).perform
  end

  # Validate callback phone number against expected phone
  # Delegates to PhoneValidationService
  def validate_callback_phone_number(callback_phone)
    WhatsappUnofficial::PhoneValidationService.new(self, callback_phone).perform
  end

  # ============================================================================
  # Adapter Delegations
  # ============================================================================

  # Raw QR code retrieval from adapter
  def qr_code
    adapter.get_qr_code
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

  # Disconnect session with status broadcast
  def disconnect_session
    adapter.disconnect_session
  end

  # Reconnect session
  def reconnect_session
    adapter.reconnect_session
  end

  # ============================================================================
  # Inbox Management
  # ============================================================================

  # Handle failed validation attempts
  def handle_failed_validation_attempts
    current_attempts = read_mismatch_attempts_from_cache
    max_attempts = 3

    Rails.logger.info "Checking failed attempts for #{phone_number}: #{current_attempts}/#{max_attempts}"

    if current_attempts >= max_attempts
      handle_max_validation_attempts_reached(current_attempts, max_attempts)
    else
      build_mismatch_response(current_attempts, max_attempts)
    end
  end

  # ============================================================================
  # Messaging (TODO: Move to adapter in future)
  # ============================================================================

  def send_message_on_gowa(message)
    message_id = send_message(message) if message.content.present?
    message_id = Waha::SendOnChannelService.new(message: message).perform if message.attachments.present?
    message_id
  end

  def send_message(_message)
    Rails.logger.warn 'send_message not yet implemented via adapter'
    nil
  end

  private

  # ============================================================================
  # Callbacks
  # ============================================================================

  def cleanup_provider_device
    Rails.logger.info "Cleaning up provider device for #{phone_number} (provider: #{effective_provider})"
    return unless provider_configured?

    cleanup_gowa_device if effective_provider == 'gowa' && device_id.present?
    cleanup_waha_session if effective_provider == 'waha' && token.present?

    Rails.logger.info "Provider device cleanup completed for #{phone_number}"
  rescue StandardError => e
    Rails.logger.error "Failed to cleanup provider device for #{phone_number}: #{e.message}"
  end

  def cleanup_gowa_device
    Rails.logger.info "Deleting GOWA device: #{device_id}"
    safe_adapter_call { adapter.logout_session }
    safe_adapter_call { adapter.delete_device }
  end

  def cleanup_waha_session
    Rails.logger.info "Disconnecting WAHA session for token: #{token}"
    safe_adapter_call { adapter.logout_session }
  end

  def safe_adapter_call
    yield
  rescue StandardError
    nil
  end

  def handle_max_validation_attempts_reached(current_attempts, max_attempts)
    Rails.logger.error "Maximum attempts reached for #{phone_number}."

    write_session_status_to_cache('disconnected')
    disconnect_waha_session
    clear_mismatch_attempts

    {
      success: false,
      attempts: current_attempts,
      max_attempts: max_attempts,
      message: "Failed to connect after #{max_attempts} attempts. Please try again later."
    }
  end

  def build_mismatch_response(current_attempts, max_attempts)
    remaining = max_attempts - current_attempts
    {
      success: false,
      attempts: current_attempts,
      max_attempts: max_attempts,
      remaining_attempts: remaining,
      message: "Phone number mismatch detected. #{remaining} attempts remaining."
    }
  end
end

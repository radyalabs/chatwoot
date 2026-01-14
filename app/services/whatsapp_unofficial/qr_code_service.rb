# frozen_string_literal: true

class WhatsappUnofficial::QrCodeService
  attr_reader :channel

  def initialize(channel)
    @channel = channel
  end

  # Get QR code with validation and device creation if needed
  # @return [Hash] Response with QR data or already_connected status
  def perform
    Rails.logger.info "Getting QR code for phone #{channel.phone_number}, provider: #{channel.effective_provider}"

    validate_not_failed!
    ensure_device_configured!

    qr_result = channel.qr_code

    handle_qr_result(qr_result)
  end

  private

  def validate_not_failed!
    cached_status = channel.read_session_status_from_cache
    return unless cached_status == 'failed'

    current_attempts = channel.read_mismatch_attempts_from_cache
    error_msg = "Cannot generate QR code - connection failed after #{current_attempts} mismatch attempts."
    Rails.logger.error error_msg
    raise StandardError, error_msg
  end

  def ensure_device_configured!
    return if channel.provider_configured?

    Rails.logger.warn "No credentials for #{channel.phone_number}. Attempting to create device..."
    begin
      channel.create_device_with_retry
      channel.reload
      Rails.logger.info 'Device created successfully.'
    rescue StandardError => e
      error_msg = "Failed to create device to get QR code: #{e.message}"
      Rails.logger.error error_msg
      raise StandardError, error_msg
    end
  end

  def handle_qr_result(qr_result)
    # Handle :already_logged_in from GOWA adapter
    if qr_result == :already_logged_in
      handle_already_logged_in
    elsif valid_qr_result?(qr_result)
      handle_success(qr_result)
    else
      handle_failure
    end
  end

  def handle_already_logged_in
    Rails.logger.info "Device #{channel.phone_number} is already logged in, updating status"
    channel.mark_as_connected!
    channel.write_session_status_to_cache('validated')
    channel.clear_mismatch_attempts
    channel.clear_rescan_attempts
    broadcast_service.session_ready

    { 'data' => { 'already_connected' => true, 'status' => 'connected' } }
  end

  def handle_success(qr_result)
    Rails.logger.info "QR code generated successfully for phone #{channel.phone_number}"
    # Mark channel as waiting for QR scan if not already connected
    channel.mark_as_waiting! unless channel.connected?
    { 'data' => { 'qr' => qr_result[:qr_data], 'qr_type' => qr_result[:qr_type].to_s } }
  end

  def handle_failure
    error_msg = 'QR code not available. Make sure device is set up and session is initialized.'
    Rails.logger.error "QR code failed for phone #{channel.phone_number}: #{error_msg}"
    raise StandardError, error_msg
  end

  def valid_qr_result?(qr_result)
    qr_result.is_a?(Hash) && qr_result[:qr_data].present?
  end

  def broadcast_service
    @broadcast_service ||= WhatsappUnofficial::BroadcastService.new(channel)
  end
end

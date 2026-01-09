# frozen_string_literal: true

class WhatsappUnofficial::PhoneValidationService
  MAX_ATTEMPTS = 3
  LOCK_TIMEOUT = 10 # seconds
  RAPID_INCREMENT_THRESHOLD = 3.0 # seconds

  attr_reader :channel, :callback_phone

  def initialize(channel, callback_phone)
    @channel = channel
    @callback_phone = callback_phone
  end

  # Validate callback phone number against expected phone
  # Uses distributed locking to prevent race conditions
  # @return [Hash] Validation result with status
  def perform
    Rails.logger.info "Validating callback phone: #{callback_phone} against expected: #{channel.phone_number}"

    with_validation_lock do
      validate_phone_match
    end
  rescue LockError => e
    Rails.logger.warn e.message
    { success: false, status: 'locked', message: 'Validation in progress or duplicate callback' }
  rescue StandardError => e
    Rails.logger.error "Error during validation: #{e.message}"
    { success: false, status: 'error', message: 'Validation error occurred' }
  end

  private

  class LockError < StandardError; end

  def with_validation_lock
    lock_key = "validation_lock_#{channel.phone_number}"
    lock_value = "#{Time.current.to_f}_#{SecureRandom.hex(4)}"

    is_locked = !::Redis::Alfred.set(lock_key, lock_value, nx: true, ex: LOCK_TIMEOUT)

    if is_locked
      handle_existing_lock(lock_key, lock_value)
      raise LockError, "Validation locked for #{channel.phone_number}"
    end

    begin
      yield
    ensure
      ::Redis::Alfred.delete(lock_key)
      Rails.logger.info "Lock released for #{channel.phone_number}"
    end
  end

  def handle_existing_lock(lock_key, lock_value)
    existing_lock_value = ::Redis::Alfred.get(lock_key)
    return unless existing_lock_value

    begin
      lock_time = existing_lock_value.split('_')[0].to_f
      time_held = Time.current.to_f - lock_time

      Rails.logger.info "Lock has been held for #{time_held.round(2)} seconds"

      if time_held > 5.0
        Rails.logger.warn "Breaking stale lock (held for #{time_held.round(2)}s)"
        ::Redis::Alfred.set(lock_key, lock_value, ex: LOCK_TIMEOUT) if ::Redis::Alfred.get(lock_key) == existing_lock_value
      end
    rescue StandardError => e
      Rails.logger.error "Error checking lock time: #{e.message}"
    end
  end

  def validate_phone_match
    expected_clean = channel.normalize_phone_number(channel.phone_number)
    callback_clean = channel.normalize_phone_number(
      Channel::WhatsappUnofficial.sanitize_phone_number(callback_phone)
    )

    Rails.logger.info "Normalized expected: #{expected_clean}, callback: #{callback_clean}"

    if expected_clean == callback_clean
      handle_match
    else
      handle_mismatch(expected_clean, callback_clean)
    end
  end

  def handle_match
    Rails.logger.info 'Phone validation SUCCESS - numbers match!'
    channel.clear_mismatch_attempts
    channel.clear_rescan_attempts
    channel.write_session_status_to_cache('validated')

    { success: true, status: 'validated', message: 'Phone number validation successful' }
  end

  def handle_mismatch(expected_clean, callback_clean)
    Rails.logger.error "Phone validation FAILED - Expected: #{expected_clean}, Got: #{callback_clean}"

    current_rescan_attempts = channel.read_rescan_attempts_from_cache
    is_rescan = current_rescan_attempts.positive?
    current_attempts = channel.increment_mismatch_attempts

    context = is_rescan ? 'rescan' : 'initial scan'
    Rails.logger.error "#{context.capitalize} mismatch attempt #{current_attempts}/#{MAX_ATTEMPTS}"

    if current_attempts >= MAX_ATTEMPTS
      handle_max_attempts_reached(current_attempts, is_rescan)
    else
      handle_retry_available(current_attempts, expected_clean, callback_clean, is_rescan)
    end
  end

  def handle_max_attempts_reached(current_attempts, is_rescan)
    Rails.logger.error "Maximum mismatch attempts (#{MAX_ATTEMPTS}) reached for #{channel.phone_number}"
    channel.write_session_status_to_cache('failed', expires_in: 1.hour)
    channel.disconnect_waha_session
    broadcast_service.session_failed(callback_phone, current_attempts)

    {
      success: false,
      status: 'failed',
      attempts: current_attempts,
      max_attempts: MAX_ATTEMPTS,
      auto_deleted: true,
      message: "Phone number validation failed after #{MAX_ATTEMPTS} attempts.",
      rescan_context: is_rescan
    }
  end

  def handle_retry_available(current_attempts, expected_clean, callback_clean, is_rescan)
    channel.write_session_status_to_cache('mismatch', expires_in: 10.minutes)
    channel.disconnect_waha_session
    broadcast_service.session_mismatch(callback_phone, current_attempts, MAX_ATTEMPTS)

    {
      success: false,
      status: 'mismatch',
      attempts: current_attempts,
      max_attempts: MAX_ATTEMPTS,
      message: 'Phone number mismatch - session logged out',
      expected_phone: expected_clean,
      connected_phone: callback_clean,
      rescan_context: is_rescan
    }
  end

  def broadcast_service
    @broadcast_service ||= WhatsappUnofficial::BroadcastService.new(channel)
  end
end

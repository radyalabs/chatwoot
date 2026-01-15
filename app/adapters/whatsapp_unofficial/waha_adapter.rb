# frozen_string_literal: true

module WhatsappUnofficial
  class WahaAdapter < BaseAdapter
    # Returns: { qr_data: String, qr_type: :base64 } or nil
    def get_qr_code
      return nil unless channel.token.present?

      log_info "Requesting QR code for phone #{channel.phone_number}"

      result = waha_service.get_qr_code_base64(api_key: channel.token)
      qr_base64 = result.dig('data', 'qr_base64')

      unless qr_base64.present?
        log_error "QR code not found in WAHA response for phone #{channel.phone_number}: #{result}"
        return nil
      end

      log_info "QR code successfully retrieved for phone #{channel.phone_number}"
      { qr_data: qr_base64, qr_type: :base64 }
    rescue StandardError => e
      log_error "Failed to get QR code for phone #{channel.phone_number}: #{e.message}"
      nil
    end

    # Returns: { connected: Boolean, status: String }
    # Status values: 'connected', 'disconnected', 'waiting', 'error'
    def get_session_status
      return { connected: false, status: 'disconnected' } unless channel.token.present?

      result = waha_service.get_session_status(api_key: channel.token)
      waha_status = result.dig('data', 'status') || 'disconnected'
      connected = waha_status.downcase == 'logged_in'

      # Normalize WAHA status to standard terminology
      normalized_status = connected ? 'connected' : 'disconnected'

      { connected: connected, status: normalized_status }
    rescue StandardError => e
      log_error "Failed to get session status for #{channel.phone_number}: #{e.message}"
      { connected: false, status: 'error' }
    end

    # Creates device and stores token
    # Returns: { token: String }
    def create_device(webhook_url:)
      raise 'WAHA not configured' unless configured?
      raise 'Webhook URL required' if webhook_url.blank?

      log_info "Creating device for phone #{channel.phone_number} with webhook #{webhook_url}"

      result = waha_service.create_device(phone_number: channel.phone_number, webhook_url: webhook_url)
      token = result.dig('data', 'token')

      raise "No token in WAHA response: #{result}" unless token.present?

      channel.update!(token: token)
      log_info "Device created successfully for phone #{channel.phone_number}, token saved"

      { token: token }
    end

    # Initialize WhatsApp session after device creation
    def initialize_session
      return nil unless channel.token.present?

      log_info "Initializing WhatsApp session for phone #{channel.phone_number}"
      result = waha_service.initialize_whatsapp_session(api_key: channel.token)
      log_info "WhatsApp session initialized for phone #{channel.phone_number}: #{result}"
      result
    rescue StandardError => e
      log_error "Failed to initialize WhatsApp session for phone #{channel.phone_number}: #{e.message}"
      nil
    end

    # Logout and clear token
    # Marks channel as intentionally disconnected to prevent future session status checks
    def logout_session
      return nil unless channel.token.present?

      log_info "Logging out WAHA session for phone #{channel.phone_number}"
      response = waha_service.logout_session(api_key: channel.token)
      log_info "WAHA session logout response for #{channel.phone_number}: #{response}"

      # Mark as intentionally disconnected to skip future session status checks
      channel.mark_as_disconnected!
      channel.update!(token: nil)
      channel.clear_session_status_cache

      response
    rescue StandardError => e
      log_error "Failed to logout WAHA session for #{channel.phone_number}: #{e.message}"
      channel.mark_as_disconnected!
      channel.update!(token: nil)
      channel.clear_session_status_cache
      nil
    end

    # Delete device from WAHA
    def delete_device
      return nil unless channel.token.present?

      log_info "Deleting device from WAHA for phone #{channel.phone_number}"
      waha_service.delete_session(api_key: channel.token)
    rescue StandardError => e
      log_warn "Delete device failed (acceptable): #{e.message}"
      nil
    end

    # Generate webhook URL for WAHA
    def webhook_url_for(phone_number)
      "#{base_url}/webhooks/waha/#{phone_number}"
    end

    # Restart session for rescanning QR
    def restart_session
      log_info "Starting complete restart for: #{channel.phone_number}"

      channel.clear_session_status_cache
      rescan_attempts = channel.increment_rescan_attempts
      log_info "This is rescan attempt ##{rescan_attempts} for #{channel.phone_number}"

      if rescan_attempts > 3
        log_error "Maximum rescan attempts (3) reached for #{channel.phone_number}"
        return handle_failed_rescan
      end

      old_token = channel.token

      if old_token.present?
        # Step 1: Logout old session
        log_info "Logging out old session for: #{channel.phone_number}"
        begin
          waha_service.logout_session(api_key: old_token)
        rescue StandardError => e
          log_warn "Logout failed (acceptable): #{e.message}"
        end

        # Step 2: Delete old device
        log_info "Deleting old device from WAHA: #{old_token}"
        begin
          waha_service.delete_session(api_key: old_token)
        rescue StandardError => e
          log_warn "Delete device failed (acceptable): #{e.message}"
        end

        # Step 3: Clear old token
        log_info 'Clearing old token from database'
        channel.update!(token: nil)
      end

      # Step 4: Create new device
      log_info "Creating new device session for #{channel.phone_number}"
      webhook_url = webhook_url_for(channel.phone_number)
      create_device(webhook_url: webhook_url)
      channel.reload

      # Step 5: Initialize new session
      if channel.token.present?
        log_info "Initializing new session with token: #{channel.token[0..8]}..."
        initialize_session
      end

      # Step 6: Set status for QR generation
      channel.mark_as_waiting!
      channel.write_session_status_to_cache('waiting')

      # Step 7: Clear QR cache
      qr_cache_key = "whatsapp_qr_#{channel.phone_number}"
      ::Redis::Alfred.delete(qr_cache_key)
      log_info "Cleared QR cache for #{channel.phone_number}"

      {
        success: true,
        message: 'New device session created. Ready for QR scanning.',
        status: 'waiting',
        method: 'complete_restart'
      }
    rescue StandardError => e
      log_error "Failed to complete restart for #{channel.phone_number}: #{e.message}"
      channel.mark_as_waiting!
      channel.write_session_status_to_cache('waiting')

      {
        success: true,
        message: 'Session reset forced. Ready for QR scanning.',
        status: 'waiting',
        method: 'force_reset',
        warning: e.message
      }
    end

    protected

    def configured?
      ENV['WAHA_API_URL'].present? && ENV['WAHA_USERNAME'].present? && ENV['WAHA_PASSWORD'].present?
    end

    private

    def waha_service
      Waha::WahaService.instance
    end

    def handle_failed_rescan
      log_error "Maximum rescan attempts reached for #{channel.phone_number}"
      channel.mark_as_disconnected!
      channel.write_session_status_to_cache('disconnected')
      logout_session
      channel.clear_rescan_attempts

      {
        success: false,
        message: 'Failed to reconnect after multiple attempts. Please try again later.'
      }
    end
  end
end

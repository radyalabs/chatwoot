# frozen_string_literal: true

module WhatsappUnofficial
  class GowaAdapter < BaseAdapter
    # Returns: { qr_data: String (URL), qr_type: :url } or nil
    def get_qr_code
      return nil unless channel.device_id.present?

      log_info "Requesting QR code for device #{channel.device_id}"

      result = gowa_service.get_qr_login(device_id: channel.device_id)
      qr_link = result.dig('results', 'qr_link')
      qr_duration = result.dig('results', 'qr_duration') || 30

      unless qr_link.present?
        log_error "QR link not found in GOWA response for device #{channel.device_id}: #{result}"
        return nil
      end

      log_info "QR code URL retrieved for device #{channel.device_id}, duration: #{qr_duration}s"
      { qr_data: qr_link, qr_type: :url, qr_duration: qr_duration }
    rescue StandardError => e
      log_error "Failed to get QR code for device #{channel.device_id}: #{e.message}"
      nil
    end

    # Returns: { connected: Boolean, status: String }
    def get_session_status
      return { connected: false, status: 'not_logged_in' } unless channel.device_id.present?

      result = gowa_service.get_device_status(device_id: channel.device_id)
      is_logged_in = result.dig('results', 'is_logged_in') || false
      is_connected = result.dig('results', 'is_connected') || false

      status = if is_logged_in
                 'logged_in'
               elsif is_connected
                 'waiting_for_qr'
               else
                 'not_logged_in'
               end

      { connected: is_logged_in, status: status }
    rescue StandardError => e
      log_error "Failed to get session status for device #{channel.device_id}: #{e.message}"
      { connected: false, status: 'error' }
    end

    # Creates device and stores device_id
    # Returns: { device_id: String }
    def create_device(webhook_url:)
      raise 'GOWA not configured' unless configured?

      # Use phone_number as device_id for easier identification
      custom_device_id = channel.phone_number
      log_info "Creating device for phone #{channel.phone_number} with device_id: #{custom_device_id}"

      result = gowa_service.create_device(device_id: custom_device_id)

      # GOWA may return device_id in different places
      device_id = result.dig('results', 'device_id') ||
                  result['device_id'] ||
                  custom_device_id

      raise "No device_id in GOWA response: #{result}" unless device_id.present?

      channel.update!(device_id: device_id)
      log_info "Device created successfully, device_id saved: #{device_id}"

      { device_id: device_id }
    end

    # GOWA doesn't require separate session initialization after device creation
    def initialize_session
      return nil unless channel.device_id.present?

      log_info "GOWA device #{channel.device_id} ready for QR scanning (no separate initialization needed)"
      { status: 'ready_for_qr' }
    end

    # Logout and clear device_id
    def logout_session
      return nil unless channel.device_id.present?

      log_info "Logging out GOWA device #{channel.device_id}"
      response = gowa_service.logout_device(device_id: channel.device_id)
      log_info "GOWA logout response for #{channel.device_id}: #{response}"

      channel.update!(device_id: nil)
      channel.clear_session_status_cache

      response
    rescue StandardError => e
      log_error "Failed to logout GOWA device #{channel.device_id}: #{e.message}"
      channel.update!(device_id: nil)
      channel.clear_session_status_cache
      nil
    end

    # Delete device from GOWA
    def delete_device
      return nil unless channel.device_id.present?

      log_info "Deleting device from GOWA: #{channel.device_id}"
      result = gowa_service.delete_device(device_id: channel.device_id)
      channel.update!(device_id: nil)
      result
    rescue StandardError => e
      log_warn "Delete device failed (acceptable): #{e.message}"
      nil
    end

    # Generate webhook URL for GOWA
    # GOWA uses a single webhook endpoint with signature verification
    def webhook_url_for(_phone_number)
      "#{base_url}/webhooks/gowa"
    end

    # Restart session for rescanning QR
    def restart_session
      log_info "Starting restart for GOWA device: #{channel.device_id}"

      channel.clear_session_status_cache
      rescan_attempts = channel.increment_rescan_attempts
      log_info "This is rescan attempt ##{rescan_attempts} for #{channel.phone_number}"

      if rescan_attempts > 3
        log_error "Maximum rescan attempts (3) reached for #{channel.phone_number}"
        return handle_failed_rescan
      end

      old_device_id = channel.device_id

      if old_device_id.present?
        # Step 1: Logout device
        log_info "Logging out GOWA device: #{old_device_id}"
        begin
          gowa_service.logout_device(device_id: old_device_id)
        rescue StandardError => e
          log_warn "Logout failed (acceptable): #{e.message}"
        end

        # Step 2: Delete device
        log_info "Deleting GOWA device: #{old_device_id}"
        begin
          gowa_service.delete_device(device_id: old_device_id)
        rescue StandardError => e
          log_warn "Delete device failed (acceptable): #{e.message}"
        end

        # Step 3: Clear device_id
        log_info 'Clearing device_id from database'
        channel.update!(device_id: nil)
      end

      # Step 4: Create new device
      log_info "Creating new GOWA device for #{channel.phone_number}"
      webhook_url = webhook_url_for(channel.phone_number)
      create_device(webhook_url: webhook_url)
      channel.reload

      # Step 5: Set status for QR generation
      channel.write_session_status_to_cache('waiting')

      {
        success: true,
        message: 'New device created. Ready for QR scanning.',
        status: 'waiting',
        method: 'gowa_restart'
      }
    rescue StandardError => e
      log_error "Failed to restart GOWA device for #{channel.phone_number}: #{e.message}"
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
      ENV['GOWA_API_URL'].present? && ENV['GOWA_API_USERNAME'].present? && ENV['GOWA_API_PASSWORD'].present?
    end

    private

    def gowa_service
      @gowa_service ||= Gowa::GowaService.new
    end

    def handle_failed_rescan
      log_error "Maximum rescan attempts reached for #{channel.phone_number}"
      channel.write_session_status_to_cache('failed', expires_in: 1.hour)
      logout_session
      channel.delete_inbox_after_failed_attempts

      {
        success: false,
        auto_deleted: true,
        message: 'Failed to reconnect after 3 rescan attempts. Inbox has been automatically removed.'
      }
    end
  end
end

# frozen_string_literal: true

module WhatsappUnofficial
  class GowaAdapter < BaseAdapter
    # Returns: { qr_data: String (URL), qr_type: :url } or nil
    # Returns :already_logged_in symbol if session is already connected
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
      # Handle ALREADY_LOGGED_IN as a special case - session is already connected
      if e.message.include?('ALREADY_LOGGED_IN')
        log_info "Device #{channel.device_id} is already logged in"
        :already_logged_in
      else
        log_error "Failed to get QR code for device #{channel.device_id}: #{e.message}"
        nil
      end
    end

    # Returns: { connected: Boolean, status: String }
    # Status values: 'connected', 'disconnected', 'waiting', 'error'
    def get_session_status
      return { connected: false, status: 'disconnected' } unless channel.device_id.present?

      # Skip API call only if channel is explicitly disconnected by user/admin
      if channel.disconnected?
        log_info "Skipping session status check - channel is disconnected"
        return { connected: false, status: 'disconnected' }
      end

      result = gowa_service.get_device_status(device_id: channel.device_id)
      is_logged_in = result.dig('results', 'is_logged_in') || false
      is_connected = result.dig('results', 'is_connected') || false

      status = if is_logged_in
                 'connected'
               elsif is_connected
                 'waiting'
               else
                 'disconnected'
               end

      { connected: is_logged_in, status: status }
    rescue StandardError => e
      log_error "Failed to get session status for device #{channel.device_id}: #{e.message}"

      # Handle DEVICE_NOT_FOUND gracefully - mark as disconnected and return disconnected
      # This stops future API calls and allows user to start fresh reconnect flow
      if e.message.include?('DEVICE_NOT_FOUND')
        log_info "Device #{channel.device_id} not found, marking channel as disconnected"
        channel.mark_as_disconnected!
        return { connected: false, status: 'disconnected' }
      end

      { connected: false, status: 'error' }
    end

    # Creates device and stores device_id
    # Returns: { device_id: String }
    def create_device(webhook_url:)
      raise 'GOWA not configured' unless configured?

      # Use environment prefix + phone_number as device_id for easier identification
      # Format: {env}_{phone_number} (e.g., staging_6281234567890, production_6281234567890)
      custom_device_id = generate_device_id(channel.phone_number)
      log_info "Creating device for phone #{channel.phone_number} with device_id: #{custom_device_id}"

      begin
        result = gowa_service.create_device(device_id: custom_device_id)

        # GOWA may return device_id in different places
        device_id = result.dig('results', 'device_id') ||
                    result['device_id'] ||
                    custom_device_id

        raise "No device_id in GOWA response: #{result}" unless device_id.present?

        channel.update!(device_id: device_id)
        log_info "Device created successfully, device_id saved: #{device_id}"

        { device_id: device_id }
      rescue StandardError => e
        # Handle "device already exists" error by cleanly recreating it
        if e.message.include?('already exists')
          log_info "Device #{custom_device_id} already exists in GOWA. Deleting and recreating..."
          
          begin
            gowa_service.logout_device(device_id: custom_device_id)
            gowa_service.delete_device(device_id: custom_device_id)
          rescue StandardError => cleanup_error
            log_warn "Cleanup failed (aman diabaikan): #{cleanup_error.message}"
          end

          result = gowa_service.create_device(device_id: custom_device_id)
          
          channel.update!(device_id: custom_device_id)
          log_info "Device recreated successfully"

          { device_id: custom_device_id, reused: false }
        else
          raise e
        end
      end
    end

    # GOWA doesn't require separate session initialization after device creation
    def initialize_session
      return nil unless channel.device_id.present?

      log_info "GOWA device #{channel.device_id} ready for QR scanning (no separate initialization needed)"
      { status: 'ready_for_qr' }
    end

    # Logout session (disconnect but keep device_id)
    # Marks channel as intentionally disconnected to prevent future session status checks
    def logout_session
      return nil unless channel.device_id.present?

      log_info "Logging out GOWA device #{channel.device_id}"
      response = gowa_service.logout_device(device_id: channel.device_id)
      log_info "GOWA logout response for #{channel.device_id}: #{response}"

      # Mark as intentionally disconnected to skip future session status checks
      channel.mark_as_disconnected!
      channel.clear_session_status_cache
      channel.write_session_status_to_cache('disconnected')

      response
    rescue StandardError => e
      log_error "Failed to logout GOWA device #{channel.device_id}: #{e.message}"
      channel.mark_as_disconnected!
      channel.clear_session_status_cache
      nil
    end

    # Disconnect session - logout and broadcast status
    # Marks channel as intentionally disconnected to prevent future session status checks
    def disconnect_session
      return { success: false, message: 'No device configured' } unless channel.device_id.present?

      log_info "Disconnecting GOWA device #{channel.device_id}"

      begin
        response = gowa_service.logout_device(device_id: channel.device_id)
        log_info "GOWA disconnect response for #{channel.device_id}: #{response}"

        # Mark as intentionally disconnected to skip future session status checks
        channel.mark_as_disconnected!
        channel.clear_session_status_cache
        channel.write_session_status_to_cache('disconnected')

        # Broadcast disconnect event
        WhatsappUnofficial::BroadcastService.new(channel).disconnect

        { success: true, message: 'Session disconnected successfully', status: 'disconnected' }
      rescue StandardError => e
        log_error "Failed to disconnect GOWA device #{channel.device_id}: #{e.message}"
        # Even if API fails, mark as disconnected to prevent further API calls
        channel.mark_as_disconnected!
        channel.clear_session_status_cache
        { success: false, message: "Failed to disconnect: #{e.message}", status: 'disconnected' }
      end
    end

    # Reconnect session
    # If device no longer exists (e.g., after logout deleted it), recreate and trigger QR flow
    def reconnect_session
      return { success: false, message: 'No device configured' } unless channel.device_id.present?

      log_info "Reconnecting GOWA device #{channel.device_id}"

      begin
        response = gowa_service.reconnect_device(device_id: channel.device_id)
        log_info "GOWA reconnect response for #{channel.device_id}: #{response}"

        channel.clear_session_status_cache

        # Check if reconnect was successful
        status = get_session_status
        if status[:connected]
          channel.mark_as_connected!
          channel.write_session_status_to_cache('connected')
          WhatsappUnofficial::BroadcastService.new(channel).reconnect
          { success: true, message: 'Session reconnected successfully', status: 'connected' }
        else
          channel.mark_as_waiting!
          channel.write_session_status_to_cache('waiting')
          { success: true, message: 'Reconnect initiated, waiting for connection', status: 'waiting' }
        end
      rescue StandardError => e
        # Handle DEVICE_NOT_FOUND by recreating the device and triggering QR flow
        if e.message.include?('DEVICE_NOT_FOUND')
          log_info "Device #{channel.device_id} not found, recreating device for fresh QR scan"
          return recreate_device_for_qr
        end

        # Handle "not logged in (session deleted)" - device exists but needs fresh QR login
        if e.message.include?('not logged in') || e.message.include?('session deleted')
          log_info "Device #{channel.device_id} exists but session deleted, triggering fresh QR scan"
          return trigger_qr_login
        end

        log_error "Failed to reconnect GOWA device #{channel.device_id}: #{e.message}"
        { success: false, message: "Failed to reconnect: #{e.message}" }
      end
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
      channel.mark_as_waiting!
      channel.write_session_status_to_cache('waiting')

      {
        success: true,
        message: 'New device created. Ready for QR scanning.',
        status: 'waiting',
        method: 'gowa_restart'
      }
    rescue StandardError => e
      log_error "Failed to restart GOWA device for #{channel.phone_number}: #{e.message}"
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

    # Returns: Array of { name: String, jid: String }
    def list_groups
      return [] unless channel.device_id.present?

      log_info "Fetching groups for device #{channel.device_id}"
      result = gowa_service.list_groups(device_id: channel.device_id)
      (result.dig('results', 'data') || []).map do |g|
        { name: g['Name'], jid: g['JID'] }
      end
    rescue StandardError => e
      log_error "Failed to fetch groups for device #{channel.device_id}: #{e.message}"
      []
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
      channel.mark_as_disconnected!
      channel.write_session_status_to_cache('disconnected')
      logout_session
      channel.clear_rescan_attempts

      {
        success: false,
        message: 'Failed to reconnect after multiple attempts. Please try again later.'
      }
    end

    # Recreate device and prepare for fresh QR scan
    # Used when GOWA device no longer exists (e.g., after logout deleted it)
    def recreate_device_for_qr
      channel.clear_session_status_cache

      # Clear existing device_id to allow fresh creation
      old_device_id = channel.device_id
      channel.update!(device_id: nil)

      log_info "Recreating device for #{channel.phone_number} (old device_id: #{old_device_id})"

      # Create new device
      webhook_url = webhook_url_for(channel.phone_number)
      create_device(webhook_url: webhook_url)
      channel.reload

      # Set status for QR generation
      channel.mark_as_waiting!
      channel.write_session_status_to_cache('waiting')

      {
        success: true,
        requires_qr: true,
        message: 'Device recreated. Please scan QR code to reconnect.',
        status: 'waiting'
      }
    rescue StandardError => e
      log_error "Failed to recreate device for #{channel.phone_number}: #{e.message}"
      { success: false, message: "Failed to recreate device: #{e.message}" }
    end

    # Trigger fresh QR login for existing device
    # Used when device exists but session was deleted/logged out
    def trigger_qr_login
      channel.clear_session_status_cache
      channel.mark_as_waiting!
      channel.write_session_status_to_cache('waiting')

      log_info "Triggering fresh QR login for device #{channel.device_id}"

      {
        success: true,
        requires_qr: true,
        message: 'Session expired. Please scan QR code to reconnect.',
        status: 'waiting'
      }
    end

    # Generate device_id with environment prefix
    # Format: {env}_{phone_number} (e.g., staging_6281234567890, production_6281234567890)
    def generate_device_id(phone_number)
      env_prefix = Rails.env.to_s
      "#{env_prefix}_#{phone_number}"
    end
  end
end

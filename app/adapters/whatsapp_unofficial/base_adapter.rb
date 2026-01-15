# frozen_string_literal: true

module WhatsappUnofficial
  class BaseAdapter
    attr_reader :channel

    def initialize(channel)
      @channel = channel
    end

    # Returns: { qr_data: String, qr_type: :base64 | :url } or nil
    def get_qr_code
      raise NotImplementedError, "#{self.class} must implement #get_qr_code"
    end

    # Returns: { connected: Boolean, status: String }
    def get_session_status
      raise NotImplementedError, "#{self.class} must implement #get_session_status"
    end

    # Creates device and stores credentials (token or device_id)
    # Returns: Hash with provider-specific identifiers
    def create_device(webhook_url:)
      raise NotImplementedError, "#{self.class} must implement #create_device"
    end

    # Initialize the WhatsApp session after device creation
    def initialize_session
      raise NotImplementedError, "#{self.class} must implement #initialize_session"
    end

    # Logout and clear session credentials
    def logout_session
      raise NotImplementedError, "#{self.class} must implement #logout_session"
    end

    # Disconnect session - logout and broadcast status change
    # Returns: { success: Boolean, message: String, status: String }
    def disconnect_session
      raise NotImplementedError, "#{self.class} must implement #disconnect_session"
    end

    # Reconnect session
    # Returns: { success: Boolean, message: String, status: String }
    def reconnect_session
      raise NotImplementedError, "#{self.class} must implement #reconnect_session"
    end

    # Delete device from provider
    def delete_device
      raise NotImplementedError, "#{self.class} must implement #delete_device"
    end

    # Generate webhook URL for this provider
    def webhook_url_for(phone_number)
      raise NotImplementedError, "#{self.class} must implement #webhook_url_for"
    end

    # Restart session for rescanning QR
    def restart_session
      raise NotImplementedError, "#{self.class} must implement #restart_session"
    end

    protected

    # Check if provider is properly configured
    def configured?
      raise NotImplementedError, "#{self.class} must implement #configured?"
    end

    def base_url
      ENV.fetch('FRONTEND_URL', 'http://localhost:3000')
    end

    def log_info(message)
      Rails.logger.info "[#{self.class.name}] #{message}"
    end

    def log_error(message)
      Rails.logger.error "[#{self.class.name}] #{message}"
    end

    def log_warn(message)
      Rails.logger.warn "[#{self.class.name}] #{message}"
    end
  end
end

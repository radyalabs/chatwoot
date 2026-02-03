# frozen_string_literal: true

class Gowa::GowaService
  API_BASE = ENV.fetch('GOWA_API_URL', nil)

  def initialize(api_url: nil)
    @api_url = api_url || API_BASE
  end

  # Create a new device slot
  # @param device_id [String, nil] Optional custom device ID
  # @return [Hash] Response with device info
  def create_device(device_id: nil)
    body = device_id.present? ? { device_id: device_id } : {}
    post('/devices', body: body)
  end

  # List all devices
  # @return [Hash] Response with devices array
  def list_devices
    get('/devices')
  end

  # Get device info
  # @param device_id [String] Device ID
  # @return [Hash] Response with device details
  def get_device(device_id:)
    get("/devices/#{encode_device_id(device_id)}")
  end

  # Delete a device
  # @param device_id [String] Device ID
  # @return [Hash] Response
  def delete_device(device_id:)
    delete("/devices/#{encode_device_id(device_id)}")
  end

  # Initiate QR code login for a device
  # GOWA uses /app/login with X-Device-Id header
  # @param device_id [String] Device ID
  # @return [Hash] Response with qr_link and qr_duration
  def get_qr_login(device_id:)
    get('/app/login', extra_headers: { 'X-Device-Id' => device_id })
  end

  # Initiate pairing code login for a device
  # GOWA uses /app/login/code with X-Device-Id header
  # @param device_id [String] Device ID
  # @param phone [String] Phone number to pair with
  # @return [Hash] Response with pairing code
  def get_pairing_code(device_id:, phone:)
    post("/app/login/code?phone=#{phone}", extra_headers: { 'X-Device-Id' => device_id })
  end

  # Logout a device
  # GOWA uses GET /app/logout with X-Device-Id header
  # @param device_id [String] Device ID
  # @return [Hash] Response
  def logout_device(device_id:)
    get('/app/logout', extra_headers: { 'X-Device-Id' => device_id })
  end

  # Reconnect a device
  # GOWA uses GET /app/reconnect with X-Device-Id header
  # @param device_id [String] Device ID
  # @return [Hash] Response
  def reconnect_device(device_id:)
    get('/app/reconnect', extra_headers: { 'X-Device-Id' => device_id })
  end

  # Get device connection status
  # GOWA uses /app/status with X-Device-Id header
  # @param device_id [String] Device ID
  # @return [Hash] Response with is_connected, is_logged_in
  def get_device_status(device_id:)
    get('/app/status', extra_headers: { 'X-Device-Id' => device_id })
  end

  # List WhatsApp groups for a device
  # @param device_id [String] Device ID
  # @return [Hash] Response with groups array
  def list_groups(device_id:)
    get('/user/my/groups', extra_headers: { 'X-Device-Id' => device_id })
  end

  def configured?
    @api_url.present? && username.present? && password.present?
  end

  private

  def get(path, extra_headers: {})
    response = HTTParty.get(
      "#{@api_url}#{path}",
      headers: auth_headers.merge(extra_headers)
    )
    handle_response(response, "GET #{path}")
  end

  def post(path, body: {}, extra_headers: {})
    response = HTTParty.post(
      "#{@api_url}#{path}",
      headers: auth_headers.merge('Content-Type' => 'application/json').merge(extra_headers),
      body: body.to_json
    )
    handle_response(response, "POST #{path}")
  end

  def delete(path, extra_headers: {})
    response = HTTParty.delete(
      "#{@api_url}#{path}",
      headers: auth_headers.merge(extra_headers)
    )
    handle_response(response, "DELETE #{path}")
  end

  def auth_headers
    {
      'Accept' => 'application/json',
      'Authorization' => "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
    }
  end

  def username
    ENV.fetch('GOWA_API_USERNAME', nil)
  end

  def password
    ENV.fetch('GOWA_API_PASSWORD', nil)
  end

  def handle_response(response, action)
    if response.success?
      Rails.logger.info "[Gowa::GowaService] #{action} succeeded"
      response.parsed_response
    else
      error_message = "#{action} failed: #{response.code} - #{response.body}"
      Rails.logger.error "[Gowa::GowaService] #{error_message}"
      raise StandardError, error_message
    end
  end

  # URL encode device_id to handle special characters like @
  def encode_device_id(device_id)
    ERB::Util.url_encode(device_id)
  end
end

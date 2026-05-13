# frozen_string_literal: true

class WhatsappUnofficial::MarkMessageReadService
  def initialize(channel:, message:)
    @channel = channel
    @message = message
  end

  def perform
    return unless should_mark_read?
    return if @message.source_id.blank?

    sender_phone = @message.additional_attributes&.dig('phone_number')
    return if sender_phone.blank?

    mark_as_read(
      message_id: @message.source_id,
      phone: "#{sender_phone}@s.whatsapp.net"
    )
  rescue StandardError => e
    Rails.logger.error("[MarkMessageRead] Failed: #{e.message}")
  end

  private

  def should_mark_read?
    @channel.provider_config&.dig('auto_mark_read') == true
  end

  def mark_as_read(message_id:, phone:)
    response = HTTParty.post(
      "#{api_base_path}/message/#{message_id}/read",
      headers: {
        'Authorization' => "Basic #{Base64.strict_encode64("#{username}:#{password}")}",
        'X-Device-Id' => @channel.device_id,
        'Content-Type' => 'application/json'
      },
      body: { phone: phone }.to_json
    )

    if response.success?
      Rails.logger.info("[MarkMessageRead] Marked #{message_id} as read")
    else
      Rails.logger.warn("[MarkMessageRead] Failed to mark read: #{response.code} #{response.body}")
    end
  end

  def api_base_path
    ENV.fetch('GOWA_API_URL', 'https://gowa.jangkau.ai')
  end

  def username
    ENV.fetch('GOWA_API_USERNAME', nil)
  end

  def password
    ENV.fetch('GOWA_API_PASSWORD', nil)
  end
end
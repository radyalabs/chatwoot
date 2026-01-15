class Webhooks::WhatsappUnofficialController < ActionController::API
  before_action :verify_signature

  def process_payload
    Webhooks::WhatsappUnofficialEventJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def verify_signature
    phone_number = params['device_id'].split('@').first
    provider = Channel::WhatsappUnofficial.where(phone_number: phone_number).pick(:provider)

    return head :unauthorized unless provider

    case provider
    when 'gowa'
      return head :unauthorized unless valid_signature?
    else
      head :unauthorized
    end
  end

  def valid_signature?
    payload   = request.raw_post
    signature = request.headers['X-Hub-Signature-256']

    return false if signature.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', webhook_secret, payload)}"
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  def webhook_secret
    ENV.fetch('GOWA_WEBHOOK_SECRET')
  end
end

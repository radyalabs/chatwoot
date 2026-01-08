class Webhooks::GowaController < ActionController::API
  before_action :verify_signature

  def process_payload
    Webhooks::GowaEventJob.perform_later(params.to_unsafe_hash)
    head :ok
  end

  private

  def verify_signature
    return if ENV['GOWA_WEBHOOK_SECRET'].blank?

    payload   = request.raw_post
    signature = request.headers['X-Hub-Signature-256']

    head :unauthorized unless valid_signature?(payload, signature)
  end

  def valid_signature?(payload, signature)
    return false if signature.blank?

    expected = "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', webhook_secret, payload)}"
    ActiveSupport::SecurityUtils.secure_compare(expected, signature)
  end

  def webhook_secret
    ENV.fetch('GOWA_WEBHOOK_SECRET')
  end
end

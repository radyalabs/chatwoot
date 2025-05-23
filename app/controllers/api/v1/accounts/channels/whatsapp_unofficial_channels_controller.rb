require 'net/http'

class Api::V1::Accounts::Channels::WhatsappUnofficialChannelsController < Api::V1::Accounts::BaseController
  def create
    account = Account.find(params[:account_id])
    user = AccountUser.find_by(account_id: account.id, inviter_id: nil)
    inbox_name = params[:inbox_name]
    phone_number = params[:phone_number]

    token = AccessToken.find_by(id: user.user_id).token

    result = ::WhatsappUnofficial::CreateWhatsappUnofficialInboxService.call(
      account_id: account.id,
      phone_number: phone_number,
      inbox_name: inbox_name,
      token: token
    )

    inbox = result[:inbox]
    webhook_url = result[:webhook_url]
    channel = result[:channel]

    qr = fetch_fonnte_qr(inbox_name, phone_number)

    if qr.blank?
      render json: { error: 'Failed to get QR from Fonnte' }, status: :bad_gateway
      return
    end

    render json: {
      webhook_url: webhook_url,
      inbox_id: inbox.id,
      channel: channel.id,
      qr_code: qr,
      message: 'WhatsApp unofficial channel created'
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique => e
    render json: { error: 'Phone number already exists' }, status: :bad_request
  end

  private

  def fetch_fonnte_qr(name, number)
    uri = URI('https://api.fonnte.com/device')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri.path, {
                                    'Content-Type' => 'application/json',
                                    'Authorization' => "Bearer #{ENV.fetch('FONNTE_API_KEY', nil)}"
                                  })
    request.body = {
      name: name,
      number: number
    }.to_json

    response = http.request(request)
    body = begin
      JSON.parse(response.body)
    rescue StandardError
      {}
    end

    body.dig('data', 'qr')
  end
end

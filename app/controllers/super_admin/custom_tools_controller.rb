class SuperAdmin::CustomToolsController < SuperAdmin::ApplicationController
  def index
    respond_to do |format|
      format.html { render :index }
      format.json do
        account_id = params[:account_id].presence
        unless account_id
          render json: [] and return
        end
        result = jangkau_get("v2/custom-tools/specs?account_id=#{account_id}")
        render json: result[:body], status: result[:status]
      end
    end
  end

  def show
    result = jangkau_get("v2/custom-tools/specs/#{params[:id]}")
    render json: result[:body], status: result[:status]
  end

  def create
    begin
      spec_data = params[:spec].is_a?(String) ? JSON.parse(params[:spec]) : params[:spec].to_unsafe_h
    rescue JSON::ParserError => e
      render json: { error: "Invalid JSON: #{e.message}" }, status: :bad_request and return
    end

    payload = {
      account_id: params[:account_id].to_i,
      name: params[:name],
      description: params[:description].presence,
      type: params[:type].presence || 'openapi',
      spec: spec_data,
    }
    payload[:base_url_override] = params[:base_url_override] if params[:base_url_override].present?

    result = jangkau_post('v2/custom-tools/specs/json', payload)
    render json: result[:body], status: result[:status]
  end

  def destroy
    result = jangkau_delete("v2/custom-tools/specs/#{params[:id]}")
    if [200, 204].include?(result[:status])
      head :no_content
    else
      render json: result[:body], status: result[:status]
    end
  end

  private

  def jangkau_base_url
    @jangkau_base_url ||= ENV.fetch('JANGKAU_AGENT_API_URL', nil)
  end

  def jangkau_api_key
    @jangkau_api_key ||= ENV.fetch('JANGKAU_AGENT_API_KEY', nil)
  end

  def jangkau_headers
    { 'Content-Type' => 'application/json', 'X-API-Key' => jangkau_api_key }
  end

  def jangkau_get(path)
    response = HTTParty.get("#{jangkau_base_url}#{path}", headers: jangkau_headers, timeout: 15)
    { body: safe_parse(response.body), status: response.code }
  rescue StandardError => e
    { body: { error: e.message }, status: 502 }
  end

  def jangkau_post(path, body)
    response = HTTParty.post(
      "#{jangkau_base_url}#{path}",
      body: body.to_json,
      headers: jangkau_headers,
      timeout: 30
    )
    { body: safe_parse(response.body), status: response.code }
  rescue StandardError => e
    { body: { error: e.message }, status: 502 }
  end

  def jangkau_delete(path)
    response = HTTParty.delete("#{jangkau_base_url}#{path}", headers: jangkau_headers, timeout: 15)
    { body: safe_parse(response.body), status: response.code }
  rescue StandardError => e
    { body: { error: e.message }, status: 502 }
  end

  def safe_parse(body)
    return nil if body.blank?
    JSON.parse(body)
  rescue JSON::ParserError
    { raw: body }
  end
end

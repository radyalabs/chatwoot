require 'httparty'

class Api::V2::Accounts::AgentSkillsController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent

  def index
    response = jangkau_request(
      :get,
      "v2/skills/?ai_agent_id=#{@ai_agent.id}&account_id=#{current_account.id}"
    )
    render json: JSON.parse(response.body), status: response.code
  end

  def create
    body = permitted_params.to_h
      .merge(ai_agent_id: @ai_agent.id, account_id: current_account.id)
      .to_json
    response = jangkau_request(:post, 'v2/skills/', body: body)
    render json: JSON.parse(response.body), status: response.code
  end

  def update
    response = jangkau_request(:patch, "v2/skills/#{params[:id]}", body: permitted_params.to_h.to_json)
    render json: JSON.parse(response.body), status: response.code
  end

  def destroy
    response = jangkau_request(:delete, "v2/skills/#{params[:id]}")
    if response.success?
      head :no_content
    else
      render json: JSON.parse(response.body), status: response.code
    end
  end

  def custom_tools
    response = jangkau_request(
      :get,
      "v2/custom-tools/attachments?ai_agent_id=#{@ai_agent.id}&account_id=#{current_account.id}"
    )
    render json: JSON.parse(response.body), status: response.code
  end

  private

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'AI Agent not found' }, status: :not_found
  end

  def permitted_params
    params.permit(:name, :description, :instructions, tool_ids: [])
  end

  def jangkau_request(method, path, body: nil)
    base_url = ENV.fetch('JANGKAU_AGENT_API_URL')
    api_key  = ENV.fetch('JANGKAU_AGENT_API_KEY')
    headers  = { 'Content-Type' => 'application/json', 'X-API-Key' => api_key }
    HTTParty.send(method, "#{base_url}#{path}", body: body, headers: headers, timeout: 30)
  end
end

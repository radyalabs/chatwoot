class Api::V1::Accounts::AiAgentsController < Api::V1::Accounts::BaseController
  include ResponseFormatChatHelper

  before_action :ai_agent, only: [:chat]
  before_action :check_max_ai_agents, only: [:create]

  def index
    ai_agents = account.ai_agents.select(:id, :account_id, :name, :description, :updated_at).order(id: :desc)
    render json: ai_agents, status: :ok
  end

  def show
    render json: ai_agent.as_detailed_json, status: :ok
  end

  def create
    return render_expired_subscription unless Current.account.subscriptions.active.exists?

    ai_agent = ai_agent_builder.perform
    render json: ai_agent.as_create_json, status: :created
  rescue StandardError => e
    handle_error('Failed to create AI Agent', exception: e)
  end

  def update
    return render_expired_subscription unless Current.account.subscriptions.active.exists?

    ai_agent = ai_agent_builder(:update).perform
    render json: ai_agent, status: :ok
  rescue StandardError => e
    handle_error('Failed to update AI Agent', exception: e)
  end

  def destroy
    ai_agent_builder(:destroy).perform
    head :no_content
  rescue StandardError => e
    handle_error('Failed to delete AI Agent', exception: e)
  end

  def chat
    conversation = Conversation.new(
      id: 0,
      uuid: params[:session_id],
      inbox_id: nil
    )

    preview_attachments = upload_preview_attachments

    Captain::Llm::AssistantChatService.new(
      params[:question],
      conversation,
      ai_agent,
      account.id,
      attachments: preview_attachments[:metadata]
    ).perform.then do |response|
      if response.success?
        response = response.parsed_response
        json_data = parsed_response(response, is_custom_agent: ai_agent.custom_agent?)
        render json: json_data, status: :ok
      else
        handle_error('Failed to generate AI response', status: :unprocessable_entity, exception: response)
      end
    end
  ensure
    # Clean up unattached preview blobs after the API call completes
    preview_attachments&.dig(:blobs)&.each(&:purge_later)
  end

  def ai_agent_templates
    agent_templates = AiAgentTemplate.jangkau.select(:id, :name, :description)
    render json: agent_templates, status: :ok
  end

  private

  def ai_agent_builder(action = :create)
    @ai_agent_builder ||= if agent_custom?
                            V2::AiAgents::AiAgentCustomBuilder.new(Current.account, params, action)
                          else
                            V2::AiAgents::AiAgentBuilder.new(Current.account, params, action)
                          end
  end

  def ai_agent
    @ai_agent ||= account.ai_agents.find(params[:id])
  end

  def account
    @account ||= Current.account
  end

  def agent_custom?
    params[:agent_type] == 'custom_agent'
  end

  MAX_PREVIEW_FILE_SIZE = 10.megabytes
  ALLOWED_PREVIEW_TYPES = %w[image/jpeg image/png image/gif image/webp].freeze

  def upload_preview_attachments
    return { metadata: [], blobs: [] } unless params[:attachments].is_a?(Array)

    blobs = []
    metadata = params[:attachments].filter_map do |file|
      next unless file.respond_to?(:tempfile)
      next if file.size > MAX_PREVIEW_FILE_SIZE
      next unless ALLOWED_PREVIEW_TYPES.include?(file.content_type)

      blob = ActiveStorage::Blob.create_and_upload!(
        io: file.tempfile,
        filename: file.original_filename,
        content_type: file.content_type
      )
      blobs << blob
      { key: blob.key, file_type: blob.content_type, filename: blob.filename.to_s }
    end

    { metadata: metadata, blobs: blobs }
  end

  def check_max_ai_agents
    render_error('Maximum number of AI agents reached') unless account.ai_agents.count < account.current_max_ai_agents
  end

  def handle_error(message, status: :bad_request, exception: nil)
    Rails.logger.error("#{message}: #{exception&.message}")
    render_error(message, status)
  end

  def render_error(message, status = :bad_request)
    render json: { error: message, message: message }, status: status
  end
end

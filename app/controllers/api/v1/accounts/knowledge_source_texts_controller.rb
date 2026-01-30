class Api::V1::Accounts::KnowledgeSourceTextsController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent

  def create
    knowledge_source = @ai_agent.knowledge_source

    unless knowledge_source
      render json: { error: 'Knowledge source not found' }, status: :not_found
      return
    end

    create_source(knowledge_source)
    upsert_document_store(knowledge_source)
  end

  def update
    knowledge_source = @ai_agent.knowledge_source

    unless knowledge_source
      render json: { error: 'Knowledge source not found' }, status: :not_found
      return
    end

    update_source(knowledge_source)
    upsert_document_store(knowledge_source)
  end

  def destroy
    knowledge_source = @ai_agent.knowledge_source
    knowledge_source_text = knowledge_source.knowledge_source_texts.find(params[:id])

    if knowledge_source_text.destroy
      delete_document_loader(store_id: knowledge_source.store_id, loader_id: knowledge_source_text.loader_id)
      upsert_document_store(knowledge_source) if knowledge_source.not_empty?
      # If the knowledge source is empty, we don't need to upsert the document store
      # because it will be deleted in the destroy method of the knowledge source.

      head :no_content
    else
      render json: { error: 'Failed to delete knowledge source text' }, status: :unprocessable_entity
    end
  end

  private

  def create_source(knowledge_source)
    # ⬇️ fallback agar text kosong tetap valid
    text = params[:text].presence || ''

    document_loader = create_document_loader(
      knowledge_source.store_id,
      "Knowledge Source - #{params[:tab]}",
      text
    )

    unless document_loader
      render json: { error: 'Failed to create document loader' }, status: :bad_gateway
      return
    end

    begin
      # ⬇️ Pastikan juga text kosong dikirim ke add_text!
      knowledge_source_text = knowledge_source.add_text!(
        content: params.merge(text: text),
        document_loader: document_loader
      )

      render json: knowledge_source_text, status: :created
    rescue StandardError => e
      delete_document_loader(store_id: knowledge_source.store_id, loader_id: document_loader['docId'])
      render json: { error: "Failed to create knowledge source: #{e.message}" }, status: :bad_gateway
    end
  end

  def update_source(knowledge_source)
    document_loader = create_document_loader(knowledge_source.store_id, "Knowledge Source - #{params[:tab]}", params[:text])

    unless document_loader
      render json: { error: 'Failed to create document loader' }, status: :bad_gateway
      return
    end

    begin
      result = nil
      ActiveRecord::Base.transaction do
        result = knowledge_source.update_text!(content: params, document_loader: document_loader)
        delete_document_loader(store_id: knowledge_source.store_id, loader_id: result[:previous_loader_id])
      end

      render json: result[:knowledge_source_text], status: :created
    rescue StandardError => e
      delete_document_loader(store_id: knowledge_source.store_id, loader_id: document_loader['docId'])
      render json: { error: "Failed to create knowledge source: #{e.message}" }, status: :bad_gateway
    end
  end

  def create_document_loader(store_id, content)
    base_url = ENV.fetch('JANGKAU_AGENT_API_URL', nil)
    api_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless base_url && api_key
      Rails.logger.error('JANGKAU_AGENT_API_URL or JANGKAU_AGENT_API_KEY not configured')
      raise StandardError, 'Knowledge management API not configured'
    end

    endpoint = "#{base_url}v2/knowledge-management/upsert-knowledge"

    response = HTTParty.post(
      endpoint,
      body: {
        index_name: params[:index_name] || 'default_index',
        store_id: store_id,
        loader_id: 'plainText',
        splitter_id: '',
        name: "QNA_#{Time.current.strftime('%Y%m%d%H%M%S')}",
        content: "#{content[:question]}\n\n#{content[:answer]}"
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => api_key # ← This was missing!
      },
      timeout: 30
    )

    # Parse and validate response
    if response.success?
      parsed = JSON.parse(response.body)

      # Validate required fields
      unless parsed['docId'] && parsed.dig('file', 'totalChunks') && parsed.dig('file', 'totalChars')
        Rails.logger.error("Invalid response format from knowledge API: #{parsed.inspect}")
        raise StandardError, 'Invalid response format from knowledge management API'
      end

      parsed
    else
      Rails.logger.error("Knowledge API request failed: #{response.code} - #{response.body}")
      raise StandardError, "Failed to create document loader: #{response.message}"
    end
  rescue HTTParty::Error, JSON::ParserError => e
    Rails.logger.error("Error calling knowledge API: #{e.message}")
    raise StandardError, "Failed to communicate with knowledge management API: #{e.message}"
  end

  # def create_document_loader(store_id, name, text)
  #   AiAgents::FlowiseService.add_document_loader(
  #     store_id: store_id,
  #     loader_id: 'plainText',
  #     splitter_id: 'recursiveCharacterTextSplitter',
  #     name: name,
  #     content: text
  #   )
  # rescue StandardError => e
  #   Rails.logger.error("Failed to add document loader: #{e.message}")
  #   nil
  # end

  def delete_document_loader(store_id:, loader_id:)
    AiAgents::FlowiseService.delete_document_loader(
      store_id: store_id,
      loader_id: loader_id
    )
  rescue StandardError => e
    Rails.logger.error("Failed to delete document loader: #{e.message}")
  end

  def upsert_document_store(knowledge_source)
    AiAgents::FlowiseService.upsert_document_store(knowledge_source.store_config)
  end

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'AI Agent not found' }, status: :not_found
  end
end

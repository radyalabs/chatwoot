class Api::V1::Accounts::KnowledgeSourceQnaController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent

  def create
    knowledge_source = @ai_agent.knowledge_source
    unless knowledge_source
      handle_error('Knowledge source not found')
      return
    end
    Rails.logger.info('+++++++++++++++++++Creating knowledge source QnA entries+++++++++++++++++++')
    Rails.logger.info("QnA Params: #{qna_params.inspect}")
    Rails.logger.info("Params: #{params.inspect}")
    Rails.logger.info("AI Agent: #{@ai_agent.inspect}")
    Rails.logger.info("Knowledge Source: #{knowledge_source.inspect}")
    create_source(knowledge_source)
    # upsert_document_store(knowledge_source)
  end

  def destroy
    Rails.logger.info('+++++++++++++++++++Deleting knowledge source QnA entry+++++++++++++++++++')

    knowledge_source = @ai_agent.knowledge_source
    qna            = knowledge_source.knowledge_source_qnas.find(params[:id])
    doc_ids        = Array(qna.loader_id) # loader_id holds the docId (or ids)
    store_id       = knowledge_source.store_id
    index_name     = params[:index_name] || 'default_index'

    Rails.logger.info("Deleting QnA id=#{qna.id}, doc_ids=#{doc_ids.inspect}, store_id=#{store_id}")

    # call external delete-knowledge endpoint
    delete_documents(index_name, doc_ids)

    if qna.destroy
      upsert_document_store(knowledge_source) if knowledge_source.not_empty?
      head :no_content
    else
      handle_error('Failed to delete knowledge source')
    end
  end

  # ---------- private ----------

  def delete_documents(index_name, document_ids)
    base_url = ENV.fetch('JANGKAU_AGENT_API_URL', nil)
    api_key  = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    raise StandardError, 'Knowledge management API not configured' unless base_url && api_key

    endpoint = "#{base_url}v2/knowledge-management/delete-knowledge"

    response = HTTParty.post(
      endpoint,
      body: {
        index_name: index_name,
        document_ids: document_ids
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => api_key
      },
      timeout: 30
    )

    unless response.success?
      Rails.logger.error("Delete knowledge API failed: #{response.code} – #{response.body}")
      raise StandardError, "Failed to delete documents: #{response.message}"
    end

    parsed = JSON.parse(response.body)
    Rails.logger.info("Delete result: #{parsed.inspect}")
    parsed
  rescue HTTParty::Error, JSON::ParserError => e
    Rails.logger.error("Error calling delete-knowledge API: #{e.message}")
    raise StandardError, "Failed to communicate with knowledge API: #{e.message}"
  end

  # def destroy
  #   Rails.logger.info('+++++++++++++++++++Deleting knowledge source QnA entry+++++++++++++++++++')

  #   knowledge_source = @ai_agent.knowledge_source
  #   qna = knowledge_source.knowledge_source_qnas.find(params[:id])

  #   doc_id = qna.loader_id # ← THIS IS docId
  #   store_id = knowledge_source.store_id

  #   Rails.logger.info("Deleting QnA id=#{qna.id}, doc_id=#{doc_id}, store_id=#{store_id}")

  #   if qna.destroy
  #     delete_document_loaders(store_id, [doc_id])
  #     upsert_document_store(knowledge_source) if knowledge_source.not_empty?
  #     head :no_content
  #   else
  #     handle_error('Failed to delete knowledge source')
  #   end
  # end

  # def destroy
  #   Rails.logger.info('+++++++++++++++++++Deleting knowledge source QnA entry+++++++++++++++++++')
  #   Rails.logger.info("Params: #{params.inspect}")
  #   knowledge_source = @ai_agent.knowledge_source
  #   knowledge_source_qna = knowledge_source.knowledge_source_qnas.find(params[:id])
  #   loader_payload = knowledge_source_qna.loader_payload # or qna.loader_id / qna.doc_id
  #   doc_id = loader_payload['docId'] # string
  #   store_id = knowledge_source.store_id
  #   Rails.logger.info("AI Agent: #{@ai_agent.inspect}")
  #   Rails.logger.info("Knowledge Source: #{knowledge_source.inspect}")
  #   Rails.logger.info("Knowledge Source QnA to be deleted: #{knowledge_source_qna.inspect}")
  #   if knowledge_source_qna.destroy
  #     delete_document_loaders(knowledge_source.store_id, [knowledge_source_qna.loader_id])
  #     upsert_document_store(knowledge_source) if knowledge_source.not_empty?
  #     # If the knowledge source is empty, we don't need to upsert the document store
  #     # because it will be deleted in the destroy method of the knowledge source.

  #     head :no_content
  #   else
  #     handle_error('Failed to delete knowledge source')
  #   end
  # end

  private

  def create_source(knowledge_source)
    Rails.logger.info('+++++++++++++++++++In create_source (batch)+++++++++++++++++++')

    created_or_updated_qnas = []
    previous_loader_ids_to_delete = []

    ActiveRecord::Base.transaction do
      # 1. Create document loaders in ONE call
      loader_results = create_document_loader_batch(
        knowledge_source.store_id,
        qna_params
      )

      # 2. Sanity check
      raise StandardError, 'Mismatch between QnAs and document loader results' if loader_results.size != qna_params.size

      # 3. Pair each QnA with its loader result
      qna_params.zip(loader_results).each do |qna, document_loader|
        Rails.logger.info("Processing QnA with docId=#{document_loader['docId']}")

        result = knowledge_source.knowledge_source_qnas.create_or_update(
          qna,
          document_loader
        )

        created_or_updated_qnas << result[:qna]
        previous_loader_ids_to_delete << result[:previous_loader_id] if result[:previous_loader_id].present?
      end
    end

    render json: created_or_updated_qnas, status: :created
  rescue StandardError => e
    handle_error(
      'Failed to create knowledge source qna (batch)',
      status: :bad_gateway,
      exception: e
    )
  end

  def create_document_loader_batch(store_id, qnas)
    base_url = ENV.fetch('JANGKAU_AGENT_API_URL', nil)
    api_key  = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless base_url && api_key
      Rails.logger.error('JANGKAU_AGENT_API_URL or JANGKAU_AGENT_API_KEY not configured')
      raise StandardError, 'Knowledge management API not configured'
    end

    endpoint = "#{base_url}v2/knowledge-management/upsert-knowledge"

    names = []
    contents = []

    qnas.each_with_index do |qna, idx|
      names << "QNA_#{Time.current.strftime('%Y%m%d%H%M%S')}_#{idx}"
      contents << "#{qna[:question]}\n\n#{qna[:answer]}"
    end

    response = HTTParty.post(
      endpoint,
      body: {
        index_name: params[:index_name] || 'default_index',
        store_id: store_id,
        loader_id: 'plainText',
        splitter_id: '',
        name: names,
        content: contents
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => api_key
      },
      timeout: 60
    )

    Rails.logger.info("Knowledge API batch response: #{response.code} - #{response.body}")
    Rails.logger.info('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
    unless response.success?
      Rails.logger.error("Knowledge API batch request failed: #{response.code} - #{response.body}")
      raise StandardError, 'Failed to create document loaders (batch)'
    end

    parsed = JSON.parse(response.body)

    documents = parsed['documents']
    unless documents.is_a?(Array) && documents.size == qnas.size
      Rails.logger.error("Invalid batch response format: #{parsed.inspect}")
      raise StandardError, 'Invalid batch response from knowledge API'
    end

    documents.each do |doc|
      unless doc['docId'] && doc.dig('file', 'totalChunks') && doc.dig('file', 'totalChars')
        raise StandardError, "Invalid document entry in batch response: #{doc.inspect}"
      end
    end

    documents
  rescue HTTParty::Error, JSON::ParserError => e
    Rails.logger.error("Error calling knowledge API (batch): #{e.message}")
    raise StandardError, "Failed to communicate with knowledge management API: #{e.message}"
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

  # def create_document_loader(store_id, content)
  #   AiAgents::FlowiseService.add_document_loader(
  #     store_id: store_id,
  #     loader_id: 'plainText',
  #     splitter_id: '',
  #     name: "QNA_#{Time.current.strftime('%Y%m%d%H%M%S')}",
  #     content: "#{content[:question]}\n\n#{content[:answer]}"
  #   )
  # end

  def delete_document_loaders(store_id, loader_ids)
    failed_deletes = []

    Array(loader_ids).each do |loader_id|
      result = AiAgents::FlowiseService.delete_document_loader(
        store_id: store_id,
        loader_id: loader_id
      )
      Rails.logger.info("Delete Document Loader Result for #{loader_id}: #{result.inspect}")
    rescue StandardError => e
      Rails.logger.error("Failed to delete document loader #{loader_id}: #{e.message}")
      failed_deletes << loader_id
    end

    return unless failed_deletes.any?

    Rails.logger.warn("Some document loaders failed to delete: #{failed_deletes.join(', ')}")
  end

  def upsert_document_store(knowledge_source)
    Rails.logger.info('+++++++++++++++++++Upserting document store+++++++++++++++++++')
    Rails.logger.info("Knowledge Source Store Config: #{knowledge_source.store_config.inspect}")
    result = AiAgents::FlowiseService.upsert_document_store(knowledge_source.store_config)
    Rails.logger.info("Upsert Document Store Result: #{result.inspect}")
  end

  def handle_error(message, status: :bad_request, exception: nil)
    Rails.logger.error("#{message}: #{exception&.message}") # Use safe navigation operator
    render_error(message, status)
  end

  def render_error(message, status = :bad_request)
    render json: { error: message }, status: status
  end

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  rescue ActiveRecord::RecordNotFound
    handle_error('AI Agent not found', :not_found)
  end

  def qna_params
    params.require(:_json).map do |qna|
      qna.permit(:id, :question, :answer, :agent_id)
    end
  end
end

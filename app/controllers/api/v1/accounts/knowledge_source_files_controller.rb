class Api::V1::Accounts::KnowledgeSourceFilesController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent
  before_action :validate_file_size, only: [:create]

  MAX_FILE_SIZE_MB = 20

  def create
    knowledge_source = @ai_agent.knowledge_source

    unless knowledge_source
      render json: { error: 'Knowledge source not found' }, status: :not_found
      return
    end
    Rails.logger.info("params[:file]: #{params[:file].inspect}")
    Rails.logger.info("params[:collection_name]: #{params[:collection_name].inspect}")
    if params[:file].blank?
      render json: { error: 'File is required' }, status: :unprocessable_entity
      return
    end

    create_source(knowledge_source, params[:file])
    # upsert_document_store(knowledge_source)
  end

  def destroy
    knowledge_source = @ai_agent.knowledge_source
    return render json: { error: 'Knowledge source not found' }, status: :not_found if knowledge_source.nil?

    knowledge_source_file = knowledge_source.knowledge_source_files.find_by(id: params[:id])
    return render json: { error: 'Knowledge source file not found' }, status: :not_found if knowledge_source_file.nil?

    if knowledge_source_file.destroy
      # Access total_chunks here
      total_chunks = knowledge_source_file.total_chunks
      doc_id = knowledge_source_file.loader_id

      # Generate chunk IDs in the same format as upsert
      chunk_ids = (0...total_chunks).map { |i| "chunk_#{i.to_s.rjust(6, '0')}:#{doc_id}" }

      delete_document_loader(
        store_id: knowledge_source.store_id,
        loader_id: chunk_ids # Pass array of chunk IDs instead of single doc_id
      )

      head :no_content
    else
      render json: { error: 'Failed to delete knowledge source file' }, status: :unprocessable_entity
    end
  end

  # def destroy
  #   knowledge_source = @ai_agent.knowledge_source
  #   return render json: { error: 'Knowledge source not found' }, status: :not_found if knowledge_source.nil?

  #   knowledge_source_file = knowledge_source.knowledge_source_files.find_by(id: params[:id])
  #   return render json: { error: 'Knowledge source file not found' }, status: :not_found if knowledge_source.nil?

  #   if knowledge_source_file.destroy
  #     delete_document_loader(store_id: knowledge_source.store_id, loader_id: knowledge_source_file.loader_id)
  #     # upsert_document_store(knowledge_source) if knowledge_source.not_empty?
  #     # If the knowledge source is empty, we don't need to upsert the document store
  #     # because it will be deleted in the destroy method of the knowledge source.

  #     head :no_content
  #   else
  #     render json: { error: 'Failed to delete knowledge source file' }, status: :unprocessable_entity
  #   end
  # end

  private

  def create_source(knowledge_source, file)
    document_loader = create_document_loader(knowledge_source.store_id, file)

    # log document loader
    Rails.logger.info("Document Loader: #{document_loader.inspect}")
    Rails.logger.info('xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx')
    unless document_loader
      render json: { error: 'Failed to create document loader' }, status: :bad_gateway
      return
    end

    begin
      knowledge_source_file = knowledge_source.add_file!(file: file, document_loader: document_loader)
      render json: knowledge_source_file, status: :created
    rescue StandardError => e
      delete_document_loader(store_id: knowledge_source.store_id, loader_id: document_loader['docId'])
      render json: { error: "Failed to create knowledge source: #{e.message}" }, status: :bad_gateway
    end
  end

  def create_document_loader(store_id, file)
    file_name = formatted_file_name(file.original_filename)
    ext = File.extname(file_name).downcase

    raise "Unsupported file type: #{ext}" unless %w[.pdf .docx].include?(ext)

    loader_id = if ext == '.pdf'
                  'pdfFile'
                else
                  'docxFile'
                end

    base64_content = convert_file_to_base64(file)

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
        index_name: params[:collection_name],
        store_id: store_id,
        loader_id: loader_id,
        splitter_id: 'recursiveCharacterTextSplitter',
        name: file_name,
        content: base64_content
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => api_key
      },
      timeout: 60
    )

    Rails.logger.info("Knowledge API file upload response: #{response.code} - #{response.body}")

    if response.success?
      parsed = JSON.parse(response.body)

      # Validate required fields
      unless parsed['docId'] && parsed.dig('file', 'totalChunks') && parsed.dig('file', 'totalChars')
        Rails.logger.error("Invalid response format from knowledge API: #{parsed.inspect}")
        raise StandardError, 'Invalid response format from knowledge management API'
      end

      parsed
    else
      Rails.logger.error("Knowledge API file upload failed: #{response.code} - #{response.body}")
      raise StandardError, "Failed to create document loader: #{response.message}"
    end
  rescue HTTParty::Error, JSON::ParserError => e
    Rails.logger.error("Error calling knowledge API for file upload: #{e.message}")
    raise StandardError, "Failed to communicate with knowledge management API: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("Failed to add document loader: #{e.message}")
    nil
  end

  def delete_document_loader(store_id:, loader_id:)
    base_url = ENV.fetch('JANGKAU_AGENT_API_URL', nil)
    api_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    raise StandardError, 'Knowledge management API not configured' unless base_url && api_key

    endpoint = "#{base_url}v2/knowledge-management/delete-knowledge"

    response = HTTParty.post(
      endpoint,
      body: {
        index_name: params[:collection_name] || 'default_index',
        document_ids: Array(loader_id)
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
  rescue StandardError => e
    Rails.logger.error("Failed to delete document loader: #{e.message}")
  end

  # def create_document_loader(store_id, file)
  #   file_name = formatted_file_name(file.original_filename)
  #   ext = File.extname(file_name).downcase

  #   raise "Unsupported file type: #{ext}" unless %w[.pdf .docx].include?(ext)

  #   loader_id = if ext == '.pdf'
  #                 'pdfFile'
  #               else
  #                 'docxFile'
  #               end

  #   base64_content = convert_file_to_base64(file, file_name)

  #   AiAgents::FlowiseService.add_document_loader(
  #     store_id: store_id,
  #     loader_id: loader_id,
  #     splitter_id: 'recursiveCharacterTextSplitter',
  #     name: file_name,
  #     content: base64_content
  #   )
  # rescue StandardError => e
  #   Rails.logger.error("Failed to add document loader: #{e.message}")
  #   nil
  # end

  # def delete_document_loader(store_id:, loader_id:)
  #   AiAgents::FlowiseService.delete_document_loader(
  #     store_id: store_id,
  #     loader_id: loader_id
  #   )
  # rescue StandardError => e
  #   Rails.logger.error("Failed to delete document loader: #{e.message}")
  # end

  def upsert_document_store(knowledge_source)
    AiAgents::FlowiseService.upsert_document_store(knowledge_source.store_config)
  end

  def formatted_file_name(file_name)
    base_name = File.basename(file_name, '.*')
    extension = File.extname(file_name)
    sanitized_name = base_name.strip.gsub(/\s+/, '_')
    random_string = SecureRandom.alphanumeric(5)

    "#{sanitized_name}_#{random_string}#{extension}"
  end

  def convert_file_to_base64(file)
    Base64.strict_encode64(file.read)
  rescue StandardError => e
    Rails.logger.error("Failed to convert file to base64: #{e.message}")
    nil
  end

  def validate_file_size
    uploaded_file = params[:file]

    if uploaded_file.nil?
      render json: { error: I18n.t('ai_agents.knowledge_source.file_size_error') }, status: :unprocessable_entity
      return
    end

    return unless uploaded_file.size > MAX_FILE_SIZE_MB.megabytes

    render json: { error: I18n.t('ai_agents.knowledge_source.file_size_error') }, status: :unprocessable_entity
  end

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'AI Agent not found' }, status: :not_found
  end
end

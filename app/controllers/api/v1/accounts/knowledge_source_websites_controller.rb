require 'uri'

class Api::V1::Accounts::KnowledgeSourceWebsitesController < Api::V1::Accounts::BaseController
  before_action :set_ai_agent

  def create
    return render_error('Knowledge source not found') if find_knowledge_source.nil?

    created_document_loader_ids = []
    collection_name = params[:collection_name]
    begin
      scrapes = fetch_scraped_content
    rescue StandardError => e
      return render_error(e.message)
    end
    begin
      processed_scrapes = process_scrapes(find_knowledge_source, scrapes, created_document_loader_ids, collection_name)
      # If the knowledge source is empty, we don't need to upsert the document store
      # because it will be deleted in the destroy method of the knowledge source.
      render json: processed_scrapes.compact, status: :created
    rescue StandardError => e
      cleanup_created_loaders(find_knowledge_source.store_id, created_document_loader_ids, collection_name)
      handle_error('Failed to create knowledge source websites', e)
    end
  end

  def update
    return render json: { error: 'Knowledge source not found' }, status: :not_found if find_knowledge_source.nil?

    collection_name = params[:collection_name]
    scrapes = [
      {
        url: params[:url],
        markdown: params[:markdown]
      }
    ]

    created_document_loader_ids = []

    begin
      processed_scrapes = process_scrapes(find_knowledge_source, scrapes, created_document_loader_ids, collection_name)
      # If the knowledge source is empty, we don't need to upsert the document store
      # because it will be deleted in the destroy method of the knowledge source.
      render json: processed_scrapes.compact, status: :created
    rescue StandardError => e
      cleanup_created_loaders(find_knowledge_source.store_id, created_document_loader_ids, collection_name)
      handle_error('Failed to create knowledge source websites', e)
    end
  end

  def destroy
    return render json: { error: 'No links provided' }, status: :bad_request if params[:ids].blank?

    collection_name = params[:collection_name]
    knowledge_source_websites = find_knowledge_source.knowledge_source_websites.where(id: params[:ids])
    return render json: { error: 'No matching knowledge source websites found' }, status: :not_found if knowledge_source_websites.blank?

    ActiveRecord::Base.transaction do
      knowledge_source_websites.each(&:destroy!)
    end

    document_loader_ids = knowledge_source_websites.flat_map do |website|
      [website.loader_id, *website.loader_ids]
    end.compact.uniq

    cleanup_created_loaders(find_knowledge_source.store_id, document_loader_ids, collection_name)

    render json: { message: 'Knowledge source websites deleted successfully' }, status: :ok
  rescue StandardError => e
    handle_error('Failed to delete knowledge source websites', e)
  end

  def collect_link
    response = Crawl4ai::MapService.new(links: [params[:url]]).perform
    render json: response, status: :ok
  rescue StandardError => e
    handle_error('Failed to collect link', e)
  end

  private

  def fetch_scraped_content
    Crawl4ai::CrawlService.new(links: params[:links]).perform
  end

  # def collect_link
  #   response = {
  #     links: [
  #       'https://example.com/page1.html',
  #       'https://example.com/about',
  #       'https://example.com/blog/article.htm',
  #       'https://example.com/products'
  #     ]
  #   }
  #   render json: response, status: :ok
  # rescue StandardError => e
  #   handle_error('Failed to collect link', e)
  # end

  # private

  # def fetch_scraped_content
  #   params[:links].map do |link|
  #     {
  #       url: link,
  #       title: 'Sample Page Title',
  #       markdown: "# Sample Page\n\nDummy content here for #{link}.",
  #       html: '<html><body><h1>Sample</h1><p>Dummy content</p></body></html>',
  #       content: "This is dummy scraped content from #{link}. Some more text here.",
  #       text: "Plain text content from #{link}",
  #       screenshot: '',
  #       links: { internal: [], external: [] },
  #       metadata: {
  #         title: 'Sample Page Title',
  #         description: 'Sample description',
  #         language: 'en'
  #       }
  #     }
  #   end
  # end

  def process_scrapes(knowledge_source, scrapes, created_ids_array, collection_name)
    store_id = knowledge_source.store_id
    document_loaders = process_scrape_to_create_document_loader(store_id, scrapes, collection_name)

    ActiveRecord::Base.transaction do
      scrapes.map do |scrape|
        process_single_scrape(knowledge_source, scrape, document_loaders, created_ids_array)
      end
    end

    scrapes
  end

  def process_scrape_to_create_document_loader(store_id, scrapes, collection_name)
    scrapes.map do |scrape|
      url = scrape[:url]
      markdown = scrape[:markdown]

      chunks = markdown.chars.each_slice(10_000).map(&:join)

      chunks.map.with_index do |chunk, index|
        url_with_index = "#{url}::[#{index + 1}/#{chunks.size}]"
        document_loader = create_document_loader(store_id, url_with_index, chunk, collection_name)
        if document_loader.nil?
          raise StandardError,
                "Failed to create document loader for scrape #{scrape[:url]} batch #{index + 1}"
        end

        document_loader
      end
    end
  end

  def process_single_scrape(knowledge_source, scrape, document_loaders, created_ids_array)
    return nil if scrape.nil?

    document_loaders = document_loaders.flatten
    matched_loaders = document_loaders.select { |loader| loader.dig('file', 'loaderName') == scrape[:url] }
    return nil if matched_loaders.empty?

    loader_ids = matched_loaders.pluck('docId')
    created_ids_array.concat(loader_ids)

    total_chars = matched_loaders.sum { |loader| loader['characters'].to_i }
    total_chunks  = matched_loaders.sum { |loader| loader.dig('file', 'totalChunks').to_i }

    create_knowledge_source_website(knowledge_source, scrape, loader_ids, total_chars, total_chunks)

    scrape
  end

  def create_knowledge_source_website(knowledge_source, scrape, loader_ids, total_chars, total_chunks)
    url = scrape[:url]
    parent_url = get_parent_url(scrape[:url])

    entity = if params[:id].present?
               knowledge_source.knowledge_source_websites.find_or_initialize_by(id: params[:id])
             else
               knowledge_source.knowledge_source_websites.new
             end

    entity.assign_attributes(
      url: url,
      parent_url: parent_url,
      content: scrape[:markdown].to_s,
      loader_id: loader_ids.first,
      loader_ids: loader_ids,
      total_chars: total_chars,
      total_chunks: total_chunks
    )
    entity.save!
    entity
  end

  def cleanup_created_loaders(store_id, loader_ids, collection_name)
    loader_ids.each do |id|
      delete_document_loader(store_id: store_id, loader_id: id, collection_name: collection_name)
    end
  end

  def handle_error(message, exception)
    Rails.logger.error("#{message}: #{exception.message}")
    render_error(message)
  end

  def render_error(message, status = :bad_request)
    render json: { error: message, message: message }, status: status
  end

  def create_document_loader(store_id, url, content, collection_name)
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
        index_name: collection_name,
        store_id: store_id,
        loader_id: 'website',
        splitter_id: '',
        name: url,
        content: "#{content}"
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

  def delete_document_loader(store_id:, loader_id:, collection_name:)
    base_url = ENV.fetch('JANGKAU_AGENT_API_URL', nil)
    api_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless base_url && api_key
      Rails.logger.error('JANGKAU_AGENT_API_URL or JANGKAU_AGENT_API_KEY not configured')
      raise StandardError, 'Knowledge management API not configured'
    end

    endpoint = "#{base_url}v2/knowledge-management/delete-knowledge"

    # Infer total_chunks from loader_id format: <total_chunks>|<some_hash>
    total_chunks = begin
      loader_id.to_s.split('|').first.to_i
    rescue StandardError
      0
    end
    response = HTTParty.post(
      endpoint,
      body: {
        index_name: collection_name,
        total_chunks: total_chunks,
        document_id: loader_id
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => api_key
      },
      timeout: 30
    )

    unless response.success?
      Rails.logger.error("Delete knowledge API failed: #{response.code} - #{response.body}")
      raise StandardError, "Failed to delete documents: #{response.message}"
    end

    JSON.parse(response.body)
  rescue HTTParty::Error, JSON::ParserError => e
    Rails.logger.error("Error calling delete-knowledge API: #{e.message}")
    raise StandardError, "Failed to communicate with knowledge API: #{e.message}"
  rescue StandardError => e
    Rails.logger.error("Failed to delete document loader: #{e.message}")
  end

  def get_parent_url(url)
    uri = URI.parse(url)
    "#{uri.scheme}://#{uri.host}"
  end

  def find_knowledge_source
    @find_knowledge_source ||= @ai_agent.knowledge_source
  end

  def set_ai_agent
    @ai_agent = Current.account.ai_agents.find(params[:ai_agent_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'AI Agent not found' }, status: :not_found
  end
end

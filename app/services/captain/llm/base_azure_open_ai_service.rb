class Captain::Llm::BaseAzureOpenAiService
  DEFAULT_DEPLOYMENT = 'gpt-5-nano'.freeze
  DEFAULT_API_VERSION = '2024-12-01-preview'.freeze
  DEFAULT_ENDPOINT = 'https://jangkau.openai.azure.com/'.freeze

  def initialize
    setup_azure_client
    Rails.logger.info("[CAPTAIN][BaseAzureOpenAiService] Initialized with model: #{@deployment_name}")
  rescue StandardError => e
    raise "Failed to initialize Azure OpenAI client: #{e.message}"
  end

  private

  def setup_azure_client
    azure_endpoint = ENV.fetch('AZURE_OPENAI_ENDPOINT', DEFAULT_ENDPOINT).presence || DEFAULT_ENDPOINT
    subscription_key = ENV.fetch('AZURE_OPENAI_SUBSCRIPTION_KEY', '').presence
    api_version = ENV.fetch('AZURE_OPENAI_API_VERSION', DEFAULT_API_VERSION).presence || DEFAULT_API_VERSION
    @deployment_name = ENV.fetch('AZURE_OPENAI_DEPLOYMENT_NAME', DEFAULT_DEPLOYMENT).presence || DEFAULT_DEPLOYMENT

    raise 'AZURE_OPENAI_SUBSCRIPTION_KEY is missing' unless subscription_key.present?

    # For Azure OpenAI, the URI must include the deployment in the path
    # Expected format: https://{resource}.openai.azure.com/openai/deployments/{deployment}/
    base_uri = azure_endpoint.end_with?('/') ? azure_endpoint : "#{azure_endpoint}/"
    @azure_uri = "#{base_uri}openai/deployments/#{@deployment_name}/"

    @client = OpenAI::Client.new(
      access_token: subscription_key,
      uri_base: @azure_uri,
      api_type: :azure,
      api_version: api_version,
      log_errors: Rails.env.development?
    )
  end
end

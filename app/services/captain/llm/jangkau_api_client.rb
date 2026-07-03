require 'httparty'

class Captain::Llm::JangkauApiClient
  include HTTParty

  LOG_PREFIX = '[Captain::Llm::JangkauApiClient]'.freeze

  base_uri ENV.fetch('JANGKAU_AGENT_API_URL', 'https://agent.jangkau.ai/')

  default_timeout 120
  open_timeout 10
  read_timeout 120

  def post_with_welcome_fallback(endpoint:, body:, headers:)
    response = self.class.post(endpoint, body: body.to_json, headers: headers)

    return response unless should_fallback_to_completion?(endpoint, response)

    Rails.logger.warn("#{LOG_PREFIX} Welcome endpoint failed (#{response.code}), falling back to /v2/chat/completion/")
    self.class.post(Captain::Llm::JangkauEndpointPolicy::COMPLETION_ENDPOINT, body: body.to_json, headers: headers)
  end

  private

  def should_fallback_to_completion?(endpoint, response)
    endpoint == Captain::Llm::JangkauEndpointPolicy::WELCOME_ENDPOINT && (!response.success? || response.parsed_response.blank?)
  end
end

class CleanupNumberingCountersJob < ApplicationJob
  queue_as :low

  # Called when an AI agent is destroyed to clean up numbering counters
  # in jangkau.langgraph database.
  #
  # @param account_id [Integer] The account ID
  # @param ai_agent_id [Integer] The AI agent ID that was deleted
  def perform(account_id, ai_agent_id)
    Rails.logger.info(
      "[CleanupNumberingCountersJob] Cleaning up counters for " \
      "account=#{account_id}, ai_agent=#{ai_agent_id}"
    )

    base_url = ENV.fetch('JANGKAU_AGENT_API_URL', nil)
    api_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless base_url.present?
      Rails.logger.warn('[CleanupNumberingCountersJob] JANGKAU_AGENT_API_URL not configured, skipping')
      return
    end

    response = HTTParty.delete(
      "#{base_url}v2/numbering/counters",
      body: {
        account_id: account_id,
        ai_agent_id: ai_agent_id
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => api_key
      },
      timeout: 10
    )

    if response.success?
      data = response.parsed_response
      Rails.logger.info(
        "[CleanupNumberingCountersJob] Successfully deleted #{data['deleted_count']} counters"
      )
    else
      Rails.logger.error(
        "[CleanupNumberingCountersJob] Failed to delete counters: #{response.code} - #{response.body}"
      )
    end
  rescue StandardError => e
    Rails.logger.error("[CleanupNumberingCountersJob] Error: #{e.message}")
    # Don't re-raise - this is a best-effort cleanup
  end
end

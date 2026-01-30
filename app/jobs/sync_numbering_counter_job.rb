class SyncNumberingCounterJob < ApplicationJob
  queue_as :default

  # Called when a user updates current_value in the Chatwoot UI to push
  # the new value to Jangkau's numbering_counters table and invalidate
  # its Redis cache.
  #
  # @param account_id [Integer] The account ID
  # @param ai_agent_id [Integer] The AI agent ID
  # @param numbering_key [String] The numbering key (e.g., "booking")
  # @param current_value [Integer] The desired next value to generate
  def perform(account_id, ai_agent_id, numbering_key, current_value)
    Rails.logger.info(
      "[SyncNumberingCounterJob] Syncing counter for " \
      "account=#{account_id}, ai_agent=#{ai_agent_id}, " \
      "key=#{numbering_key}, current_value=#{current_value}"
    )

    base_url = ENV.fetch('JANGKAU_AGENT_API_URL', nil)
    api_key = ENV.fetch('JANGKAU_AGENT_API_KEY', nil)

    unless base_url.present?
      Rails.logger.warn('[SyncNumberingCounterJob] JANGKAU_AGENT_API_URL not configured, skipping')
      return
    end

    response = HTTParty.put(
      "#{base_url}v2/numbering/counters",
      body: {
        account_id: account_id,
        ai_agent_id: ai_agent_id,
        numbering_key: numbering_key,
        current_value: current_value
      }.to_json,
      headers: {
        'Content-Type' => 'application/json',
        'X-API-Key' => api_key
      },
      timeout: 10
    )

    if response.success?
      Rails.logger.info(
        "[SyncNumberingCounterJob] Successfully synced counter: #{response.parsed_response}"
      )
    else
      Rails.logger.error(
        "[SyncNumberingCounterJob] Failed to sync counter: #{response.code} - #{response.body}"
      )
    end
  rescue StandardError => e
    Rails.logger.error("[SyncNumberingCounterJob] Error: #{e.message}")
  end
end

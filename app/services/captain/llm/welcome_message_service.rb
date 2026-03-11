# frozen_string_literal: true

require 'httparty'

class Captain::Llm::WelcomeMessageService
  include HTTParty

  DEFAULT_TIMEOUT = 60
  DEFAULT_OPEN_TIMEOUT = 10
  DEFAULT_READ_TIMEOUT = 60

  base_uri ENV.fetch('JANGKAU_AGENT_API_URL', 'https://agent.jangkau.ai/')

  def initialize(conversation)
    @conversation = conversation
    @ai_agent = @conversation.inbox&.ai_agent
  end

  def perform
    if api_key.blank?
      Rails.logger.warn('[CAPTAIN][WelcomeMessageService] Missing config: JANGKAU_AGENT_API_KEY')
      return nil
    end

    if @ai_agent.blank?
      Rails.logger.warn(
        "[CAPTAIN][WelcomeMessageService] Skipping: inbox has no ai_agent conversation_id=#{@conversation.id} inbox_id=#{@conversation.inbox_id}"
      )
      return nil
    end

    base_prompt = welcome_prompt
    prompt_image_urls = extract_markdown_image_urls(base_prompt)

    prompt_text = prompt_with_context(base_prompt)
    if prompt_text.blank?
      Rails.logger.warn(
        "[CAPTAIN][WelcomeMessageService] Missing welcome prompt. Set JANGKAU_WELCOME_PROMPT or configure ai_agent.flow_data agents_config[0].bot_prompt.handover_welcome_message conversation_id=#{@conversation.id} ai_agent_id=#{@ai_agent.id}"
      )
      return nil
    end

    timeouts = timeouts_config
    Rails.logger.info(
      "[CAPTAIN][WelcomeMessageService] Using timeouts total=#{timeouts[:timeout]}s open=#{timeouts[:open_timeout]}s read=#{timeouts[:read_timeout]}s source=#{timeouts[:source]}"
    )

    response = self.class.post(
      '/v2/chat/welcome/',
      body: request_body(prompt_text).to_json,
      headers: headers,
      timeout: timeouts[:timeout],
      open_timeout: timeouts[:open_timeout],
      read_timeout: timeouts[:read_timeout]
    )

    Rails.logger.info("[CAPTAIN][WelcomeMessageService] POST /v2/chat/welcome/ -> status=#{response.code}")

    if !response&.respond_to?(:success?) || !response.success?
      body_preview = response&.body.to_s
      body_preview = body_preview[0, 2000]
      Rails.logger.warn(
        "[CAPTAIN][WelcomeMessageService] Non-2xx response status=#{response&.code} body=#{body_preview.inspect}"
      )
    end

    return nil unless response&.respond_to?(:success?) && response.success?

    parsed = response.parsed_response
    parsed = JSON.parse(response.body) if parsed.is_a?(String)
    return nil unless parsed.is_a?(Hash)

    text = parsed['response'].presence || parsed['message'].presence
    return nil if text.blank?

    image_urls = []
    image_urls.concat(prompt_image_urls) if prompt_image_urls.present?
    image_urls.concat(extract_image_urls(parsed) || [])
    image_urls.concat(env_image_urls || [])
    image_urls = image_urls.map { |u| u.to_s.strip }.reject(&:blank?).uniq
    image_urls = nil if image_urls.blank?

    if image_urls.present?
      { text: text, image_urls: image_urls }
    else
      text
    end
  rescue JSON::ParserError
    nil
  rescue StandardError => e
    Rails.logger.error("[CAPTAIN][WelcomeMessageService] HTTP call failed: #{e.class}: #{e.message}")
    nil
  end

  private

  def api_key
    ENV.fetch('JANGKAU_AGENT_API_KEY', nil)
  end

  def headers
    {
      'Content-Type' => 'application/json',
      'Accept' => 'application/json',
      'X-API-Key' => api_key
    }
  end

  def request_body(prompt_text)
    {
      prompt: prompt_text,
      attachments: nil,
      overrideConfig: override_config
    }
  end

  def extract_image_urls(parsed)
    raw = parsed['image_urls'] || parsed['images'] || parsed['attachments']
    return nil if raw.blank?

    if raw.is_a?(Array)
      urls = raw.filter_map do |item|
        if item.is_a?(String)
          item
        elsif item.is_a?(Hash)
          item['url'] || item[:url]
        end
      end

      urls.map { |u| u.to_s.strip }.reject(&:blank?).uniq
    elsif raw.is_a?(String)
      raw.to_s.strip.presence&.then { |u| [u] }
    end
  end

  def env_image_urls
    raw = ENV.fetch('JANGKAU_WELCOME_IMAGE_URLS', nil)
    return nil if raw.blank?

    raw.split(',').map(&:strip).reject(&:blank?).uniq
  end

  def extract_markdown_image_urls(markdown)
    markdown = markdown.to_s
    return nil if markdown.blank?

    urls = markdown.scan(/!\[[^\]]*\]\(([^)]+)\)/).flatten
    urls = urls.map do |raw|
      candidate = raw.to_s.strip
      # Strip optional title: (url "title") or (url 'title')
      candidate = candidate.split(/\s+/, 2).first.to_s.strip
      candidate = candidate.delete_prefix('<').delete_suffix('>')
      candidate
    end

    urls.reject(&:blank?).uniq
  rescue StandardError
    nil
  end

  def override_config
    {
      session_id: @conversation.uuid,
      conversation_id: @conversation.id,
      ai_agent_id: @ai_agent&.id,
      inbox_id: @conversation.inbox_id,
      vars: vars_config
    }
  end

  def vars_config
    base_vars = {
      'account_id' => @conversation.account_id.to_s,
      'customer_name' => @conversation.contact&.name || '',
      'contact' => contact_payload.to_s,
      'channel' => @conversation.inbox&.channel_type || ''
    }

    first_message = first_user_message
    base_vars['first_user_message'] = first_message if first_message.present?

    flow_data = @ai_agent&.flow_data || {}
    merged = base_vars.merge(flow_data)

    # Ensure required fields exist for LangGraph schema
    merged['type'] ||= 'welcome'
    merged['agents_config'] ||= [default_agent_config]

    merged
  end

  def welcome_prompt
    env_prompt = ENV.fetch('JANGKAU_WELCOME_PROMPT', nil)
    return env_prompt if env_prompt.present?

    flow_data = @ai_agent&.flow_data || {}
    from_flow = flow_data.dig('agents_config', 0, 'bot_prompt', 'handover_welcome_message')
    return from_flow if from_flow.present?

    from_flow = flow_data.dig(:agents_config, 0, :bot_prompt, :handover_welcome_message)
    return from_flow if from_flow.present?

    nil
  end

  def first_user_message
    content = @conversation.messages.incoming.where(private: false).order(:created_at).limit(1).pluck(:content).first
    content.to_s.strip
  rescue StandardError
    ''
  end

  def prompt_with_context(base_prompt)
    base_prompt = base_prompt.to_s
    return base_prompt if base_prompt.blank?

    user_text = first_user_message
    return base_prompt if user_text.blank?

    normalized = user_text.gsub(/\s+/, ' ').strip
    normalized = normalized[0, 500]

    # Allow prompt templates to explicitly reference the first user message.
    replaced = base_prompt.gsub('{{first_user_message}}', normalized).gsub('{first_user_message}', normalized)
    return replaced if replaced != base_prompt

    # Default behavior: append small context + style guardrails.
    <<~PROMPT.strip
      #{base_prompt}

      Context:
      - first_user_message: #{normalized.inspect}

      Instructions:
      - Do NOT greet or say hello again.
      - Write a short follow-up promo message tailored to the user's message.
      - Assume the sales agent already answered the question; this is an additional promo.
      - Keep it to 2-4 sentences, no bullet points, no emoji.
    PROMPT
  end

  def contact_payload
    contact = @conversation.contact
    return nil if contact.blank?

    # LangGraph schema expects `contact` to be a string.
    contact.phone_number.presence || contact.email.presence || contact.identifier.presence || contact.id.to_s
  end

  def default_agent_config
    {
      agent_id: 'default',
      type: 'default',
      temperature: 0.3,
      bot_prompt: {
        persona: '',
        instructions: '',
        handover_conditions: '',
        business_info: nil,
        handover_welcome_message: welcome_prompt
      },
      configurations: {},
      collection_name: 'default',
      tools: []
    }
  end

  def timeouts_config
    open_timeout, open_source = integer_env(
      %w[JANGKAU_WELCOME_OPEN_TIMEOUT JANGKAU_AGENT_API_OPEN_TIMEOUT],
      DEFAULT_OPEN_TIMEOUT
    )

    read_timeout, read_source = integer_env(
      %w[JANGKAU_WELCOME_READ_TIMEOUT JANGKAU_WELCOME_TIMEOUT JANGKAU_AGENT_API_READ_TIMEOUT JANGKAU_AGENT_TIMEOUT],
      DEFAULT_READ_TIMEOUT
    )

    total_timeout, total_source = integer_env(
      %w[JANGKAU_WELCOME_TIMEOUT JANGKAU_AGENT_TIMEOUT],
      read_timeout
    )

    {
      timeout: total_timeout,
      open_timeout: open_timeout,
      read_timeout: read_timeout,
      source: "total=#{total_source} open=#{open_source} read=#{read_source}"
    }
  end

  def integer_env(keys, fallback)
    keys.each do |key|
      raw = ENV.fetch(key, nil)
      next if raw.blank?

      value = raw.to_i
      return [value, key] if value.positive?
    end

    [fallback.to_i, 'default']
  end
end

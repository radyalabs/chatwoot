class Captain::Copilot::Config::DebounceConfig
  DEFAULT_DEBOUNCE_ENABLED = true
  DEFAULT_INTERVAL_SECONDS = 10
  DEFAULT_MAX_WAIT_SECONDS = 60
  MIN_INTERVAL_SECONDS = 5
  MIN_MAX_WAIT_SECONDS = 30

  def self.for_message(message)
    new(message: message)
  end

  def self.for_conversation(conversation)
    new(conversation: conversation)
  end

  def initialize(message: nil, conversation: nil)
    @message = message
    @conversation = conversation || message&.conversation
  end

  def enabled?
    return false unless global_enabled?
    return false if agent_enabled.nil?
    return false unless agent_enabled
    return true if valid_agent_config?

    log_invalid_agent_config
    false
  end

  def interval_seconds
    return global_interval_seconds unless agent_enabled == true && valid_agent_config?

    parsed_interval_seconds
  end

  def max_wait_seconds
    return global_max_wait_seconds unless agent_enabled == true && valid_agent_config?

    parsed_max_wait_seconds
  end

  private

  def global_enabled?
    parse_boolean(ENV.fetch('CAPTAIN_DEBOUNCE_ENABLED', DEFAULT_DEBOUNCE_ENABLED.to_s)) == true
  end

  def global_interval_seconds
    parsed = parse_integer(ENV.fetch('CAPTAIN_DEBOUNCE_INTERVAL_SECONDS', DEFAULT_INTERVAL_SECONDS.to_s))
    return DEFAULT_INTERVAL_SECONDS if parsed.nil? || parsed < 1

    parsed
  end

  def global_max_wait_seconds
    parsed = parse_integer(ENV.fetch('CAPTAIN_DEBOUNCE_MAX_WAIT_SECONDS', DEFAULT_MAX_WAIT_SECONDS.to_s))
    return DEFAULT_MAX_WAIT_SECONDS if parsed.nil? || parsed < 1

    parsed
  end

  def agent_config
    @agent_config ||= begin
      display_flow_data = ai_agent&.display_flow_data
      config = display_flow_data&.dig('debounce_config') || display_flow_data&.dig(:debounce_config)
      config.is_a?(Hash) ? config : nil
    end
  end

  def ai_agent
    @ai_agent ||= if @message
                    Captain::Copilot::State::MessageContext.new(@message).ai_agent
                  elsif @conversation
                    AgentBotInbox.where.not(ai_agent_id: nil).find_by(status: :inactive, inbox_id: @conversation.inbox_id)&.ai_agent
                  end
  end

  def agent_enabled
    @agent_enabled ||= parse_boolean(agent_value('enabled'))
  end

  def parsed_interval_seconds
    @parsed_interval_seconds ||= parse_integer(agent_value('interval_seconds'))
  end

  def parsed_max_wait_seconds
    @parsed_max_wait_seconds ||= parse_integer(agent_value('max_wait_seconds'))
  end

  def valid_agent_config?
    return false if parsed_interval_seconds.nil? || parsed_max_wait_seconds.nil?
    return false if parsed_interval_seconds < MIN_INTERVAL_SECONDS
    return false if parsed_max_wait_seconds < MIN_MAX_WAIT_SECONDS

    parsed_max_wait_seconds >= parsed_interval_seconds
  end

  def agent_value(key)
    return nil unless agent_config

    return agent_config[key] if agent_config.key?(key)
    return agent_config[key.to_sym] if agent_config.key?(key.to_sym)

    nil
  end

  def parse_boolean(value)
    return value if [true, false].include?(value)

    case value
    when String
      normalized = value.strip.downcase
      return true if normalized == 'true'
      return false if normalized == 'false'
    end

    nil
  end

  def parse_integer(value)
    return value if value.is_a?(Integer)
    return unless value.is_a?(String)
    return unless value.match?(/\A\d+\z/)

    value.to_i
  end

  def log_invalid_agent_config
    return if @invalid_config_logged

    Rails.logger.warn(
      '[Captain::Copilot::Config::DebounceConfig] invalid per-agent debounce config, forcing direct dispatch | ' \
      "ai_agent_id=#{ai_agent&.id} | interval_seconds=#{agent_value('interval_seconds').inspect} | " \
      "max_wait_seconds=#{agent_value('max_wait_seconds').inspect}"
    )
    @invalid_config_logged = true
  end
end

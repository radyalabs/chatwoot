module SheetNumbering
  class GenerateNextNumberService
    TOKENS = {
      '[NUMBER]' => :padded_number,
      '[MONTH]' => :month_two_digit,
      '[YEAR]' => :year_four_digit,
      '[YEAR_SHORT]' => :year_two_digit,
      '[MONTH_ROMAN]' => :month_roman,
      '[MONTH_SHORT]' => :month_short,
      '[MONTH_LONG]' => :month_long
    }.freeze

    ROMAN_NUMERALS = %w[I II III IV V VI VII VIII IX X XI XII].freeze

    def initialize(account_id:, ai_agent_id:)
      @account_id = account_id
      @ai_agent_id = ai_agent_id
    end

    def perform
      config = find_config!

      # Use pessimistic locking to prevent race conditions
      config.with_lock do
        # Generate formatted ID with current value
        formatted_id = generate_formatted_id(config)

        # Increment current_value and update timestamp
        config.update!(
          current_value: config.current_value + 1,
          updated_at: Time.current
        )

        {
          formatted_id: formatted_id,
          current_value: config.current_value
        }
      end
    end

    private

    def find_config!
      config = SheetNumberingConfig.find_by(
        account_id: @account_id,
        ai_agent_id: @ai_agent_id
      )
      raise ActiveRecord::RecordNotFound, "Sheet numbering config not found for account_id=#{@account_id}, ai_agent_id=#{@ai_agent_id}" unless config

      config
    end

    def generate_formatted_id(config)
      now = Time.current.in_time_zone('Asia/Jakarta')
      result = config.format_pattern.dup

      TOKENS.each do |token, method|
        result.gsub!(token, send(method, config, now))
      end

      config.prefix.present? ? "#{config.prefix}#{result}" : result
    end

    def padded_number(config, _now)
      config.current_value.to_s.rjust(config.number_padding, '0')
    end

    def month_two_digit(_config, now)
      now.month.to_s.rjust(2, '0')
    end

    def year_four_digit(_config, now)
      now.year.to_s
    end

    def year_two_digit(_config, now)
      now.year.to_s[-2..]
    end

    def month_roman(_config, now)
      ROMAN_NUMERALS[now.month - 1]
    end

    def month_short(_config, now)
      now.strftime('%b').upcase
    end

    def month_long(_config, now)
      now.strftime('%B').upcase
    end
  end
end

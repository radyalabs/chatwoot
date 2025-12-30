module Reminders
  class UpsertService
    INDEX_ELEMENTS = [:account_id, :inbox_id, :ai_agent_id, :conversation_id, :service_id].freeze
    UPDATABLE_COLUMNS = [:scheduled_at, :contact, :customer_name, :service_name,
                         :service_type, :service_location].freeze

    def initialize(params)
      @params = params.to_h.symbolize_keys
    end

    def perform
      validate_index_elements!
      existing = find_existing_reminder
      existing ? update_with_null_preservation(existing) : create_new_reminder
    end

    private

    def validate_index_elements!
      missing = INDEX_ELEMENTS.select { |col| @params[col].blank? }
      raise ArgumentError, "Missing required index elements: #{missing.join(', ')}" if missing.any?
    end

    def find_existing_reminder
      Reminder.find_by(@params.slice(*INDEX_ELEMENTS))
    end

    def update_with_null_preservation(reminder)
      update_attrs = {}
      UPDATABLE_COLUMNS.each do |col|
        # Only update if key exists in params AND value is not nil
        update_attrs[col] = @params[col] if @params.key?(col) && !@params[col].nil?
      end
      reminder.update!(update_attrs) if update_attrs.any?
      reminder
    end

    def create_new_reminder
      Reminder.create!(@params.slice(*INDEX_ELEMENTS, *UPDATABLE_COLUMNS))
    end
  end
end

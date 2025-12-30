module Reminders
  class BatchDeleteService
    INDEX_ELEMENTS = [:account_id, :inbox_id, :ai_agent_id, :conversation_id, :service_id].freeze

    def initialize(records)
      @records = records.map { |r| r.to_h.symbolize_keys }
    end

    def perform
      return 0 if @records.blank?

      validate_records!

      # Build OR conditions for each record
      conditions = @records.map do |record|
        Reminder.where(record.slice(*INDEX_ELEMENTS))
      end

      # Combine with OR and delete
      combined_query = conditions.reduce { |result, condition| result.or(condition) }
      combined_query.delete_all
    end

    private

    def validate_records!
      @records.each_with_index do |record, idx|
        missing = INDEX_ELEMENTS.select { |col| record[col].blank? }
        raise ArgumentError, "Record #{idx}: missing required fields: #{missing.join(', ')}" if missing.any?
      end
    end
  end
end

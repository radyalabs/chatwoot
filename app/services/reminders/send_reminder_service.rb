module Reminders
  class SendReminderService
    class ReminderError < StandardError; end

    def initialize(reminder, config = nil)
      @reminder = reminder
      @config = config || reminder.ai_agent&.reminder_config
    end

    def perform
      validate!

      message_content = build_message_content
      create_message(message_content)
      @reminder.mark_as_sent!

      Rails.logger.info("[SendReminderService] Successfully sent reminder ##{@reminder.id}")
      true
    rescue ReminderError => e
      Rails.logger.warn("[SendReminderService] Skipped reminder ##{@reminder.id}: #{e.message}")
      false
    rescue StandardError => e
      Rails.logger.error("[SendReminderService] Failed to send reminder ##{@reminder.id}: #{e.message}")
      Rails.logger.error(e.backtrace&.first(5)&.join("\n"))
      false
    end

    private

    def validate!
      raise ReminderError, 'Config not found or disabled' unless @config&.enabled?
      raise ReminderError, 'Reminder already sent' if @reminder.sent_reminder_count.positive?
      raise ReminderError, 'Scheduled time is missing' if @reminder.scheduled_at.blank?
      raise ReminderError, 'Conversation not found' unless @reminder.conversation_id.present?
    end

    def build_message_content
      @config.render_message(@reminder)
    end

    def create_message(content)
      Message.create!(
        content: content,
        account_id: @reminder.account_id,
        inbox_id: @reminder.inbox_id,
        conversation_id: @reminder.conversation_id,
        message_type: :template,
        content_type: :text,
        status: :sent
      )
    end
  end
end
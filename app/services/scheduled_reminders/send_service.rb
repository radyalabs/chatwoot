module ScheduledReminders
  class SendService
    include ChannelMessageSender

    def initialize(reminder)
      @reminder = reminder
    end

    def perform
      validate!

      inbox = @reminder.inbox
      channel_type = @reminder.receiver_channel_type
      validate_inbox_channel(inbox, channel_type)

      receiver_source_id = normalize_receiver_source_id(channel_type, @reminder.receiver_address)
      raise 'Receiver source_id could not be resolved' if receiver_source_id.blank?

      send_to_channel(inbox, channel_type, receiver_source_id, @reminder.message_template)

      @reminder.advance_occurrence!

      Rails.logger.info("[ScheduledReminders] Sent reminder ##{@reminder.id} '#{@reminder.title}'")
    rescue StandardError => e
      Rails.logger.error("[ScheduledReminders] Failed to send reminder ##{@reminder.id}: #{e.message}")
      raise
    end

    private

    def validate!
      raise 'Reminder is disabled' unless @reminder.enabled?
      raise 'No next occurrence scheduled' if @reminder.next_occurrence_at.nil?
      raise 'Inbox not found' if @reminder.inbox.nil?
    end
  end
end

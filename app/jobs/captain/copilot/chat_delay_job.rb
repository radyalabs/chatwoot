module Captain
  module Copilot
    class ChatDelayJob < ApplicationJob
      queue_as :chat_delay

      def perform(conversation_id)
        Rails.logger.info "[BOT] Delay job fired for Conv: #{conversation_id}"

        Sidekiq.redis { |redis| redis.del("jangkau:chat_lock:#{conversation_id}") }

        bot_reply_id = Message.where(conversation_id: conversation_id)
                              .where(sender_type: 'AiAgent')
                              .reorder(id: :desc)
                              .limit(1)
                              .pick(:id) || 0

        pending_messages = Message.where(conversation_id: conversation_id)
                                  .incoming
                                  .where(private: false)
                                  .where('id > ?', bot_reply_id)
                                  .reorder(id: :asc)

        if pending_messages.empty?
          Rails.logger.info "[BOT] No pending messages for Conv: #{conversation_id}, nothing to send"
          return
        end

        message = pending_messages.last
        combined_text = pending_messages.map(&:content).compact.join("\n")
        Rails.logger.info "[JANGKAU] Sending #{pending_messages.size} pending message(s) for Conv: #{conversation_id} | msg_id=#{message.id}"

        Captain::Copilot::ChatService.new(message, combined_text).perform

        Rails.logger.info "[JANGKAU] Delay job completed for Conv: #{conversation_id}"
      rescue StandardError => e
        Rails.logger.error "[CRITICAL ERROR JANGKAU JOB] Conv: #{conversation_id} | #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        raise
      end
    end
  end
end

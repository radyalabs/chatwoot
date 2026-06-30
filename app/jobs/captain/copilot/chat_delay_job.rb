module Captain
  module Copilot
    class ChatDelayJob < ApplicationJob
      queue_as :chat_delay

      def perform(conversation_id)
        Rails.logger.info "[BOT] Delay job fired for Conv: #{conversation_id}"

        last_processed_key = "jangkau:last_msg_id:#{conversation_id}"
        last_processed_id = Sidekiq.redis { |r| r.get(last_processed_key) }.to_i

        bot_reply_id = Message.where(conversation_id: conversation_id)
                              .where(sender_type: 'AiAgent')
                              .reorder(id: :desc)
                              .limit(1)
                              .pick(:id) || 0

        start_id = [last_processed_id, bot_reply_id].max

        pending_messages = Message.where(conversation_id: conversation_id)
                                  .incoming
                                  .where(private: false)
                                  .where('id > ?', start_id)
                                  .reorder(id: :asc)

        if pending_messages.empty?
          Rails.logger.info "[BOT] No pending messages for Conv: #{conversation_id}, nothing to send"
          Sidekiq.redis { |redis| redis.del("jangkau:chat_lock:#{conversation_id}") }
          return
        end

        message = pending_messages.last
        combined_text = pending_messages.map(&:content).compact.join("\n")
        
        Sidekiq.redis { |r| r.set(last_processed_key, message.id, ex: 86400) }

        Sidekiq.redis { |redis| redis.del("jangkau:chat_lock:#{conversation_id}") }

        Rails.logger.info "[JANGKAU] Sending #{pending_messages.size} pending message(s) for Conv: #{conversation_id} | msg_id=#{message.id}"

        Captain::Copilot::ChatService.new(message, combined_text).perform_combined

        Rails.logger.info "[JANGKAU] Delay job completed for Conv: #{conversation_id}"
      rescue StandardError => e
        Rails.logger.error "[CRITICAL ERROR JANGKAU JOB] Conv: #{conversation_id} | #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        Sidekiq.redis { |redis| redis.del("jangkau:chat_lock:#{conversation_id}") }
        raise
      end
    end
  end
end
module Captain
  module Copilot
    class ChatDelayJob < ApplicationJob
      queue_as :chat_delay

      def perform(conversation_id, _last_message_id)
        timer_key    = "jangkau:chat_timer:#{conversation_id}"
        buffer_key   = "jangkau:chat_buffer:#{conversation_id}"
        lock_key     = "jangkau:chat_lock:#{conversation_id}"
        last_msg_key = "jangkau:chat_last_msg:#{conversation_id}"

        execute_at = nil
        Sidekiq.redis { |redis| execute_at = redis.get(timer_key).to_i }

        if execute_at.zero?
          Rails.logger.warn "[BOT] Timer key missing/expired for Conv: #{conversation_id}, proceeding with buffer flush"
        elsif Time.current.to_i < (execute_at - 2)
          Rails.logger.info "[BOT] Job fired too early for Conv: #{conversation_id}, bailing"
          return
        end

        messages = []
        last_message_id = nil

        Sidekiq.redis do |redis|
          messages        = redis.lrange(buffer_key, 0, -1)
          last_message_id = redis.get(last_msg_key).to_i
          redis.del(buffer_key, timer_key, lock_key, last_msg_key)
        end

        if messages.empty?
          Rails.logger.info "[BOT] Buffer empty for Conv: #{conversation_id}, nothing to send"
          return
        end

        if last_message_id.zero?
          Rails.logger.warn "[BOT] last_msg_key missing for Conv: #{conversation_id}, using first buffered message as fallback"
        end

        message = Message.find_by(id: last_message_id)

        unless message
          Rails.logger.error "[JANGKAU] Message not found: #{last_message_id}"
          return
        end

        combined_text = messages.join("\n")
        Rails.logger.info "[JANGKAU] Sending #{messages.size} buffered message(s) for Conv: #{conversation_id} | last_msg_id=#{message.id}"

        Captain::Copilot::ChatService.new(message, combined_text).perform

        Rails.logger.info "[JANGKAU] Delay job completed for Conv: #{conversation_id}"
      rescue StandardError => e
        Sidekiq.redis { |redis| redis.del("jangkau:chat_lock:#{conversation_id}") }
        Rails.logger.error "[CRITICAL ERROR JANGKAU JOB] Conv: #{conversation_id} | #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        raise
      end
    end
  end
end

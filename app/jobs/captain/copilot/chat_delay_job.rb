module Captain
  module Copilot
    class ChatDelayJob < ApplicationJob
      queue_as :send_reply_with_attachments

      def perform(conversation_id, last_message_id)
        timer_key = "jangkau:chat_timer:#{conversation_id}"
        buffer_key = "jangkau:chat_buffer:#{conversation_id}"

        execute_at = nil
        Sidekiq.redis do |redis|
          execute_at = redis.get(timer_key).to_i
        end

        if Time.current.to_i < (execute_at - 2)
          return
        end

        messages = []
        Sidekiq.redis do |redis|
          messages = redis.lrange(buffer_key, 0, -1)
          redis.del(buffer_key)
          redis.del(timer_key)
        end

        return if messages.empty?

        combined_text = messages.join("\n")
        message = Message.find_by(id: last_message_id)

        unless message
          Rails.logger.error "[DEBUG JANGKAU] Gagal menemukan message_id: #{last_message_id}"
          return
        end

        Rails.logger.info "[DEBUG JANGKAU] Mengirim #{messages.size} pesan gabungan ke AI..."
        Captain::Copilot::ChatService.new(message, combined_text).perform

      rescue StandardError => e
        Rails.logger.error "\n[CRITICAL ERROR JANGKAU JOB] #{e.class}: #{e.message}"
      end
    end
  end
end
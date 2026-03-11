# frozen_string_literal: true

module Conversations
  class WelcomeMessageJob < ApplicationJob
    queue_as :default

    def perform(conversation_id)
      return unless welcome_enabled?

      conversation = Conversation.find(conversation_id)

      Rails.logger.info(
        "[Conversations::WelcomeMessageJob] Start conversation_id=#{conversation.id} inbox_id=#{conversation.inbox_id}"
      )

      custom_attrs = conversation.custom_attributes || {}
      if custom_attrs['jangkau_welcome_sent']
        Rails.logger.info(
          "[Conversations::WelcomeMessageJob] Skipping (already sent) conversation_id=#{conversation.id}"
        )
        return
      end

      result = Captain::Llm::WelcomeMessageService.new(conversation).perform

      welcome_text = if result.is_a?(Hash)
                       result[:text] || result['text']
                     else
                       result
                     end

      image_urls = if result.is_a?(Hash)
                     result[:image_urls] || result['image_urls']
                   else
                     nil
                   end

      if welcome_text.blank?
        Rails.logger.warn(
          "[Conversations::WelcomeMessageJob] No welcome text returned conversation_id=#{conversation.id}"
        )
        return
      end

      ai_agent = conversation.inbox&.ai_agent

      # Match the main Jangkau completion reply behavior so the widget shows the AI agent name (e.g., "Sales").
      attrs = {
        content: welcome_text,
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        conversation_id: conversation.id,
        message_type: 'outgoing',
        content_type: 'text',
        status: 'sent',
        private: false,
        additional_attributes: { 'jangkau' => { 'welcome' => true } }
      }

      if ai_agent.present?
        attrs[:sender_type] = 'AiAgent'
        attrs[:sender_id] = ai_agent.id
      end

      Message.create!(attrs)

      if image_urls.present?
        urls = Array(image_urls).map { |u| u.to_s.strip }.reject(&:blank?)
        if urls.any?
          Rails.logger.info("[Conversations::WelcomeMessageJob] Enqueue #{urls.count} welcome image(s) conversation_id=#{conversation.id}")
          urls.each_with_index do |url, idx|
            Captain::Copilot::AttachMessageImageJob.perform_later(attrs, url, idx + 1)
          end
        end
      end

      Rails.logger.info(
        "[Conversations::WelcomeMessageJob] Welcome message created conversation_id=#{conversation.id}"
      )

      conversation.update!(custom_attributes: custom_attrs.merge('jangkau_welcome_sent' => true))
    rescue ActiveRecord::RecordNotFound
      nil
    rescue StandardError => e
      Rails.logger.error("[Conversations::WelcomeMessageJob] Failed: #{e.class}: #{e.message}")
      nil
    end

    private

    def welcome_enabled?
      raw = ENV.fetch('JANGKAU_WELCOME_ENABLED', nil)
      return false if raw.blank?

      %w[1 true yes y on].include?(raw.to_s.strip.downcase)
    end
  end
end

# frozen_string_literal: true

module WhatsappUnofficial
  module PhoneNormalizable
    extend ActiveSupport::Concern

    # Instance method to normalize phone number
    def normalize_phone_number(phone)
      self.class.normalize_phone_number(phone)
    end

    class_methods do
      # Normalize phone number to international format
      # @param phone [String] Phone number to normalize
      # @return [String, nil] Normalized phone number or nil
      def normalize_phone_number(phone)
        return nil if phone.blank?

        normalized = phone.gsub(/\D/, '')

        case normalized
        when /^62/
          normalized # Already in international format
        when /^08/
          "62#{normalized[1..]}" # Convert 08xxx to 628xxx
        when /^0/
          "62#{normalized[1..]}" # Convert 0xxx to 62xxx
        else
          normalized # Return as is for other formats
        end
      end

      # Extract phone number from WhatsApp chat ID
      # @param chat_id [String] Chat ID like "6282164497019@s.whatsapp.net"
      # @return [String, nil] Extracted phone number
      def extract_phone_number(chat_id)
        return nil if chat_id.blank?

        phone = chat_id.split.first
        phone&.gsub(/@.*$/, '')
      end

      # Extract phone from "from" field which can have complex formats
      # Handles: "6281281631785@s.whatsapp.net"
      #          "6285842516470:31@s.whatsapp.net in 6281281631785@s.whatsapp.net"
      # @param from_field [String] From field value
      # @return [String, nil] Extracted phone number
      def extract_phone_from_from_field(from_field)
        return nil if from_field.blank?

        case from_field.to_s
        when /^(\d+):?\d*@.*\sin\s(\d+)@/
          # Group chat format - get the second number (recipient)
          ::Regexp.last_match(2)
        when /^(\d+):?\d*@/
          # Simple format - get the first number
          ::Regexp.last_match(1)
        else
          # Fallback: get all digits before @
          from_field.to_s.split('@').first&.gsub(/\D/, '')
        end
      end

      # Remove WhatsApp suffixes and clean phone number
      # @param phone [String] Phone number to sanitize
      # @return [String, nil] Sanitized phone number
      def sanitize_phone_number(phone)
        return nil if phone.blank?

        sanitized = phone.to_s
                         .gsub(/@(s\.whatsapp\.net|c\.us)$/, '') # Remove WhatsApp domain
                         .gsub(/:\d+$/, '') # Remove device ID (e.g., :31)
                         .gsub(/\D/, '') # Keep only digits

        sanitized.presence
      end

      # Determine event type from callback params
      # @param params [Hash] Callback parameters
      # @return [String] Event type: 'receipt', 'message', 'initial_scan', or 'unknown'
      def determine_event_type(params)
        if params[:event] == 'receipt'
          Rails.logger.info 'Detected RECEIPT callback'
          return 'receipt'
        end

        if params.key?(:from) && params.key?(:isFromMe) && params.key?(:message)
          if params[:pushname].present?
            Rails.logger.info 'Detected REGULAR MESSAGE (incoming, outgoing, with reply, etc.)'
            return 'message'
          elsif params[:isFromMe] == true && params[:pushname].blank?
            Rails.logger.info 'Detected INITIAL SCAN callback'
            return 'initial_scan'
          end
        end

        Rails.logger.info 'Unknown callback structure'
        'unknown'
      end

      # Check if message is an initial scan message (QR code was just scanned)
      # @param params [Hash] Callback parameters
      # @return [Boolean] True if this is an initial scan message
      def initial_scan_message?(params)
        # Initial scan message characteristics:
        # - isFromMe = true
        # - No pushname (key differentiator)
        # - Simple "from" format (not group chat)
        # - Message only has id, no text/body/caption
        # - Not a group message

        return false unless params[:isFromMe] == true
        return false if params[:pushname].present?
        return false if params[:from].to_s.include?(' in ')

        message = params[:message] || {}
        return false if message[:text].present?
        return false if message[:body].present?
        return false if message[:caption].present?
        return false unless message[:id].present?
        return false if params[:isGroup] == true

        Rails.logger.info "DETECTED INITIAL SCAN MESSAGE - From: #{params[:from]}, IsFromMe: #{params[:isFromMe]}"
        true
      end

      # Extract connected phone number from callback payload
      # @param payload [Hash] Callback payload
      # @return [String, nil] Connected phone number
      def extract_connected_phone_number(payload)
        connected_phone = payload[:phone_number] ||
                          payload[:phone] ||
                          extract_phone_from_from_field(payload[:from]) ||
                          payload[:jid]&.gsub(/@.*$/, '') ||
                          payload.dig(:info, :phone_number) ||
                          payload.dig(:session, :phone_number)

        sanitize_phone_number(connected_phone)
      end
    end

    # Validate that callback phone matches expected phone
    # @param callback_phone [String] Phone number from callback
    # @return [Boolean] True if phones match
    def validate_phone_number_consistency(callback_phone)
      return true if callback_phone.blank?

      expected_clean = normalize_phone_number(phone_number)
      connected_clean = normalize_phone_number(self.class.sanitize_phone_number(callback_phone))

      Rails.logger.info "PHONE VALIDATION: Expected: #{phone_number} -> #{expected_clean}, Connected: #{callback_phone} -> #{connected_clean}"
      Rails.logger.info "Match result: #{expected_clean == connected_clean}"

      expected_clean == connected_clean
    end
  end
end

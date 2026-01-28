# frozen_string_literal: true

module WhatsappUnofficial
  class AdapterFactory
    ADAPTERS = {
      'waha' => 'WhatsappUnofficial::WahaAdapter',
      'gowa' => 'WhatsappUnofficial::GowaAdapter'
    }.freeze

    class << self
      def for(channel)
        provider = resolve_provider(channel)
        adapter_class = adapter_class_for(provider)

        adapter_class.new(channel)
      end

      def default_provider
        return 'gowa' if gowa_configured?
        return 'waha' if waha_configured?

        'waha' # fallback
      end

      def available_providers
        providers = []
        providers << 'waha' if waha_configured?
        providers << 'gowa' if gowa_configured?
        providers
      end

      private

      def resolve_provider(channel)
        channel.provider.presence || default_provider
      end

      def adapter_class_for(provider)
        class_name = ADAPTERS[provider]
        raise ArgumentError, "Unknown WhatsApp provider: #{provider}. Available: #{ADAPTERS.keys.join(', ')}" unless class_name

        class_name.constantize
      end

      def waha_configured?
        ENV['WAHA_API_URL'].present?
      end

      def gowa_configured?
        ENV['GOWA_API_URL'].present?
      end
    end
  end
end

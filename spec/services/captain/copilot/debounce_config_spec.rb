require 'rails_helper'

RSpec.describe Captain::Copilot::DebounceConfig do
  def build_config(message:, debounce_config:)
    ai_agent = instance_double(AiAgent, id: 9, display_flow_data: { 'debounce_config' => debounce_config })
    context = instance_double(Captain::Copilot::MessageContext, ai_agent: ai_agent)
    allow(Captain::Copilot::MessageContext).to receive(:new).with(message).and_return(context)
    described_class.for_message(message)
  end

  describe '#enabled?' do
    it 'disables debounce when global kill-switch is false' do
      message = instance_double(Message, conversation: nil)
      config = build_config(message: message, debounce_config: {
                              'enabled' => true,
                              'interval_seconds' => 10,
                              'max_wait_seconds' => 60
                            })

      with_modified_env CAPTAIN_DEBOUNCE_ENABLED: 'false' do
        expect(config.enabled?).to be(false)
      end
    end

    it 'falls back to global setting when per-agent config is missing' do
      message = instance_double(Message, conversation: nil)
      context = instance_double(Captain::Copilot::MessageContext, ai_agent: nil)
      allow(Captain::Copilot::MessageContext).to receive(:new).with(message).and_return(context)

      with_modified_env CAPTAIN_DEBOUNCE_ENABLED: 'true' do
        expect(described_class.for_message(message).enabled?).to be(true)
      end
    end

    it 'disables debounce when agent config explicitly sets enabled false' do
      message = instance_double(Message, conversation: nil)
      config = build_config(message: message, debounce_config: {
                              'enabled' => false,
                              'interval_seconds' => 15,
                              'max_wait_seconds' => 60
                            })

      with_modified_env CAPTAIN_DEBOUNCE_ENABLED: 'true' do
        expect(config.enabled?).to be(false)
      end
    end

    it 'enables debounce and uses per-agent values when config is valid' do
      message = instance_double(Message, conversation: nil)
      config = build_config(message: message, debounce_config: {
                              'enabled' => true,
                              'interval_seconds' => 15,
                              'max_wait_seconds' => 60
                            })

      with_modified_env CAPTAIN_DEBOUNCE_ENABLED: 'true' do
        expect(config.enabled?).to be(true)
        expect(config.interval_seconds).to eq(15)
        expect(config.max_wait_seconds).to eq(60)
      end
    end

    it 'forces direct dispatch when enabled true but interval is invalid' do
      message = instance_double(Message, conversation: nil)
      config = build_config(message: message, debounce_config: {
                              'enabled' => true,
                              'interval_seconds' => 3,
                              'max_wait_seconds' => 60
                            })

      with_modified_env CAPTAIN_DEBOUNCE_ENABLED: 'true' do
        expect(config.enabled?).to be(false)
      end
    end
  end

  describe '#max_wait_seconds' do
    it 'resolves per-agent values from conversation scope' do
      message = instance_double(Message, conversation: nil)
      config = build_config(message: message, debounce_config: {
                              'enabled' => true,
                              'interval_seconds' => 15,
                              'max_wait_seconds' => 75
                            })

      with_modified_env CAPTAIN_DEBOUNCE_ENABLED: 'true' do
        expect(config.max_wait_seconds).to eq(75)
      end
    end
  end
end

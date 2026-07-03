require 'rails_helper'

RSpec.describe AiAgent do
  describe 'default debounce config' do
    let(:account) { create(:account) }

    it 'sets debounce defaults when display_flow_data is blank' do
      ai_agent = described_class.create!(
        account: account,
        name: 'Debounce Bot',
        system_prompts: 'prompt',
        welcoming_message: 'welcome',
        timezone: 'UTC',
        template_type: 'jangkau',
        agent_type: 'single_agent',
        flow_data: {},
        display_flow_data: {}
      )

      expect(ai_agent.display_flow_data['debounce_config']).to eq(
        'enabled' => false,
        'interval_seconds' => 15,
        'max_wait_seconds' => 60
      )
    end

    it 'preserves provided debounce settings on create' do
      ai_agent = described_class.create!(
        account: account,
        name: 'Configured Debounce Bot',
        system_prompts: 'prompt',
        welcoming_message: 'welcome',
        timezone: 'UTC',
        template_type: 'jangkau',
        agent_type: 'single_agent',
        flow_data: {},
        display_flow_data: {
          'debounce_config' => {
            'enabled' => true,
            'interval_seconds' => 20,
            'max_wait_seconds' => 90
          }
        }
      )

      expect(ai_agent.display_flow_data['debounce_config']).to eq(
        'enabled' => true,
        'interval_seconds' => 20,
        'max_wait_seconds' => 90
      )
    end
  end
end

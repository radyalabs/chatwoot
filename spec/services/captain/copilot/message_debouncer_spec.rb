require 'rails_helper'

RSpec.describe Captain::Copilot::MessageDebouncer do
  let(:message) { instance_double('Message', id: 45, conversation_id: 12) }
  let(:job_proxy) { instance_double('ActiveJob::ConfiguredJob', perform_later: true) }
  let(:debounce_config) { instance_double(Captain::Copilot::DebounceConfig, interval_seconds: interval_seconds) }
  let(:interval_seconds) { 10 }

  before do
    allow(Captain::Copilot::DebounceConfig).to receive(:for_message).with(message).and_return(debounce_config)
  end

  describe '#schedule' do
    it 'schedules process job with resolved debounce interval' do
      expect(Captain::Copilot::ProcessDebouncedConversationJob).to receive(:set)
        .with(wait: 10.seconds)
        .and_return(job_proxy)
      expect(job_proxy).to receive(:perform_later).with(12, 45)

      described_class.new(message).schedule
    end

    it 'uses per-agent debounce interval when configured' do
      allow(debounce_config).to receive(:interval_seconds).and_return(25)

      expect(Captain::Copilot::ProcessDebouncedConversationJob).to receive(:set)
        .with(wait: 25.seconds)
        .and_return(job_proxy)
      expect(job_proxy).to receive(:perform_later).with(12, 45)

      described_class.new(message).schedule
    end
  end
end

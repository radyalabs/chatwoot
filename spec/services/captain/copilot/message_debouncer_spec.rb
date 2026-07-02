require 'rails_helper'

RSpec.describe Captain::Copilot::MessageDebouncer do
  let(:message) { instance_double('Message', id: 45, conversation_id: 12) }
  let(:job_proxy) { instance_double('ActiveJob::ConfiguredJob', perform_later: true) }

  describe '#schedule' do
    it 'schedules process job with default debounce interval' do
      expect(Captain::Copilot::ProcessDebouncedConversationJob).to receive(:set)
        .with(wait: 10.seconds)
        .and_return(job_proxy)
      expect(job_proxy).to receive(:perform_later).with(12, 45)

      described_class.new(message).schedule
    end

    it 'uses debounce interval from environment when present' do
      expect(Captain::Copilot::ProcessDebouncedConversationJob).to receive(:set)
        .with(wait: 25.seconds)
        .and_return(job_proxy)
      expect(job_proxy).to receive(:perform_later).with(12, 45)

      with_modified_env CAPTAIN_DEBOUNCE_INTERVAL_SECONDS: '25' do
        described_class.new(message).schedule
      end
    end
  end
end

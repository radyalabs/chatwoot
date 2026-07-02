require 'rails_helper'

RSpec.describe Captain::Copilot::ChatServiceJob do
  let(:usage_incrementer) { instance_double(Subscriptions::IncrementUsageService, perform: true) }
  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) { create(:message, message_type: 'incoming', conversation: conversation, inbox: inbox, account: account) }
  let(:chat_service) { instance_double(Captain::Copilot::ChatService, perform: true) }

  before do
    allow(Subscriptions::IncrementUsageService).to receive(:new).and_return(usage_incrementer)
    allow(Captain::Copilot::ChatService).to receive(:new).and_return(chat_service)
  end

  describe '#perform' do
    it 'keeps backward compatibility for legacy single-argument invocation' do
      expect(Captain::Copilot::ChatService).to receive(:new).with(
        message,
        combined_question: nil,
        attachments: nil
      ).and_return(chat_service)

      described_class.perform_now(message.id)
    end

    it 'forwards combined question and attachments for debounced invocation' do
      combined_question = "first line\nsecond line"
      attachments = [{ key: 'blob-key', file_type: 'image/png', filename: 'avatar.png', url: 'https://example.com/file' }]

      expect(Captain::Copilot::ChatService).to receive(:new).with(
        message,
        combined_question: combined_question,
        attachments: attachments
      ).and_return(chat_service)

      described_class.perform_now(message.id, combined_question: combined_question, attachments: attachments)
    end

    it 'tracks debounce invocation failure metric when perform raises' do
      message_id = 999
      allow_any_instance_of(described_class).to receive(:load_message_with_attachments).and_raise(StandardError, 'boom')
      allow(ActiveSupport::Notifications).to receive(:instrument)

      expect(ActiveSupport::Notifications).to receive(:instrument).with(
        'captain.debounce.ai_invocation_failure',
        hash_including(message_id: message_id, error: 'StandardError')
      )

      expect { described_class.new.perform(message_id) }.to raise_error(StandardError, 'boom')
    end
  end
end

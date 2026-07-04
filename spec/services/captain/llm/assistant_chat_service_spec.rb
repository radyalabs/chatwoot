require 'rails_helper'

RSpec.describe Captain::Llm::AssistantChatService do
  let(:account_id) { 1 }
  let(:message) { instance_double(Message) }
  let(:conversation) { instance_double(Conversation) }
  let(:ai_agent) { instance_double(AiAgent, custom_agent?: false) }
  let(:attachments) { [{ key: 'blob-key', file_type: 'image/png', filename: 'image.png', url: 'https://example.com/image.png' }] }
  let(:context) do
    {
      account_id: account_id,
      ai_agent: ai_agent,
      conversation: conversation,
      message: message
    }
  end
  let(:jangkau_service) { instance_double(Captain::Llm::BaseJangkauService, perform: response) }
  let(:response) { instance_double(HTTParty::Response) }

  before do
    allow(Captain::Llm::BaseJangkauService).to receive(:new).and_return(jangkau_service)
  end

  describe '#perform' do
    it 'defaults Jangkau requests to completion intent' do
      described_class.new(context: context, attachments: attachments).perform

      expect(Captain::Llm::BaseJangkauService).to have_received(:new).with(
        context: context,
        preview_attachments: attachments,
        intent: :completion
      )
    end

    it 'forwards explicit welcome intent to Jangkau requests' do
      described_class.new(context: context, attachments: attachments, intent: :welcome).perform

      expect(Captain::Llm::BaseJangkauService).to have_received(:new).with(
        context: context,
        preview_attachments: attachments,
        intent: :welcome
      )
    end
  end
end

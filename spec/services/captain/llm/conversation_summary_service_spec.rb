require 'rails_helper'

RSpec.describe Captain::Llm::ConversationSummaryService do
  let(:account) { create(:account, custom_attributes: {}) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:service) { described_class.new(conversation) }
  let(:client) { instance_double(OpenAI::Client) }

  before do
    allow(OpenAI::Client).to receive(:new).and_return(client)
    allow_any_instance_of(Subscriptions::IncrementUsageService).to receive(:perform)
  end

  describe '#perform' do
    let(:openai_response) do
      {
        'choices' => [
          {
            'message' => {
              'content' => "**Permintaan Klien**\nKlien ingin refund order #12345 karena produk tidak sesuai.\n\n**Perlu Ditindaklanjuti**\n- Bot tidak bisa memproses refund secara langsung."
            }
          }
        ]
      }
    end

    context 'when Azure OpenAI responds successfully' do
      before { allow(client).to receive(:chat).and_return(openai_response) }

      it 'returns the summary text' do
        result = service.perform
        expect(result).to include('Permintaan Klien')
        expect(result).to include('#12345')
      end

      it 'saves summary to the conversation' do
        service.perform
        expect(conversation.reload.ai_summary).to include('Permintaan Klien')
      end

      it 'sets ai_summary_generated_at' do
        service.perform
        expect(conversation.reload.ai_summary_generated_at).to be_present
      end
    end

    context 'when account locale is set to English' do
      let(:account) { create(:account, locale: :en) }

      before { allow(client).to receive(:chat).and_return(openai_response) }

      it 'uses English headers in the system prompt' do
        service.perform
        expect(client).to have_received(:chat) do |params|
          system_content = params[:parameters][:messages].find { |m| m[:role] == 'system' }[:content]
          expect(system_content).to include('Customer Request')
          expect(system_content).to include('Follow-up Needed')
        end
      end
    end

    context 'when Azure OpenAI raises an error' do
      before do
        allow(client).to receive(:chat).and_raise(StandardError.new('API timeout'))
      end

      it 'logs the error and raises' do
        expect(Rails.logger).to receive(:error).with(/ConversationSummaryService.*API timeout/)
        expect(Rails.logger).to receive(:error).with(/Error details:/)
        expect { service.perform }.to raise_error(StandardError)
      end
    end
  end
end

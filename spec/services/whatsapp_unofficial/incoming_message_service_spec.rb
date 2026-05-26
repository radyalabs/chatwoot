require 'rails_helper'

RSpec.describe WhatsappUnofficial::IncomingMessageService do
  describe '#perform' do
    subject(:service) { described_class.new(inbox: inbox, params: params) }

    let(:account) { create(:account) }
    let(:channel) { create(:channel_whatsapp_unofficial, account: account) }
    let(:inbox) { create(:inbox, account: account, channel: channel) }
    let(:params) do
      {
        'event' => 'message',
        'device_id' => '628987654321@s.whatsapp.net',
        'payload' => {
          'id' => '3EB0C127D7BACC83D6A1',
          'from' => '628123456789@s.whatsapp.net',
          'from_name' => 'John Doe',
          'chat_id' => '628987654321@s.whatsapp.net',
          'timestamp' => '2023-10-15T10:30:00Z',
          'body' => 'Hello'
        }
      }
    end

    before do
      allow_any_instance_of(Subscriptions::IncrementUsageService)
        .to receive(:perform).and_return(true)
    end

    it 'creates a new message' do
      expect { service.perform }.to change(Message, :count).by(1)
    end

    it 'does not create duplicate message when source_id already exists' do
      service.perform
      expect { service.perform }.not_to change(Message, :count)
    end

    it 'is idempotent when called multiple times' do
      3.times { service.perform }
      expect(Message.where(source_id: '3EB0C127D7BACC83D6A1').count).to eq(1)
    end

    it 'creates message when source_id is different' do
      service.perform

      different_params = params.deep_merge('payload' => { 'id' => '3EB0C127D7BACC83D6A2' })
      described_class.new(inbox: inbox, params: different_params).perform

      expect(Message.where(source_id: %w[3EB0C127D7BACC83D6A1 3EB0C127D7BACC83D6A2]).count).to eq(2)
    end
  end
end

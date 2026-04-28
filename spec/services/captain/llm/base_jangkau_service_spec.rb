require 'rails_helper'

RSpec.describe Captain::Llm::BaseJangkauService do
  before do
    incrementer = instance_double(Subscriptions::IncrementUsageService, perform: true)
    allow(Subscriptions::IncrementUsageService).to receive(:new).and_return(incrementer)
  end

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, inbox: inbox, account: account) }
  let(:ai_agent) { instance_double('AiAgent', id: 123, flow_data: {}) }

  def build_service(message)
    described_class.new(account.id, ai_agent, conversation, message)
  end

  describe 'reply context enrichment' do
    context 'when incoming message replies to another message (in_reply_to)' do
      it 'prefixes question with replied message content' do
        replied = create(
          :message,
          conversation: conversation,
          account: account,
          inbox: inbox,
          message_type: :incoming,
          content: 'quoted content'
        )

        incoming = create(
          :message,
          conversation: conversation,
          account: account,
          inbox: inbox,
          message_type: :incoming,
          content: 'current content',
          additional_attributes: { 'channel' => 'WhatsappUnofficial' },
          content_attributes: { in_reply_to: replied.id }
        )

        service = build_service(incoming)
        question = service.instance_variable_get(:@question)

        expect(question).to include('User replied to:')
        expect(question).to include('quoted content')
        expect(question).to include('User message:')
        expect(question).to include('current content')
      end
    end

    context 'when message has gowa quoted_text but no resolvable replied message' do
      it 'uses gowa_reply.quoted_text as context' do
        incoming = create(
          :message,
          conversation: conversation,
          account: account,
          inbox: inbox,
          message_type: :incoming,
          content: 'current content',
          additional_attributes: { 'channel' => 'WhatsappUnofficial' },
          content_attributes: { gowa_reply: { quoted_text: 'quoted from payload' } }
        )

        service = build_service(incoming)
        question = service.instance_variable_get(:@question)

        expect(question).to include('User replied to:')
        expect(question).to include('quoted from payload')
        expect(question).to include('current content')
      end
    end

    context 'when message is not WhatsappUnofficial' do
      it 'does not enrich question' do
        replied = create(
          :message,
          conversation: conversation,
          account: account,
          inbox: inbox,
          message_type: :incoming,
          content: 'quoted content'
        )

        incoming = create(
          :message,
          conversation: conversation,
          account: account,
          inbox: inbox,
          message_type: :incoming,
          content: 'current content',
          additional_attributes: { 'channel' => 'Other' },
          content_attributes: { in_reply_to: replied.id }
        )

        service = build_service(incoming)
        question = service.instance_variable_get(:@question)

        expect(question).to eq('current content')
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Captain::Copilot::WelcomeSourceClaimer do
  subject(:claimer) { described_class.new(message) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox) }
  let(:message) do
    create(
      :message,
      message_type: :incoming,
      sender: conversation.contact,
      account: account,
      inbox: inbox,
      conversation: conversation,
      private: private_message
    )
  end
  let(:private_message) { false }
  let(:ai_agent) do
    AiAgent.create!(
      account: account,
      name: 'Jangkau Agent',
      agent_type: :single_agent,
      template_type: :jangkau,
      flow_data: {},
      display_flow_data: {}
    )
  end

  before do
    allow(Subscriptions::IncrementUsageService).to receive(:new).and_return(instance_double(Subscriptions::IncrementUsageService, perform: true))
    AgentBotInbox.create!(inbox: inbox, ai_agent: ai_agent, status: :inactive)
  end

  describe '#claim?' do
    it 'claims the current message when it is the first incoming public contact message' do
      expect(claimer.claim?).to be(true)
      expect(conversation.reload.captain_welcome_source_message_id).to eq(message.id)
    end

    context 'when the marker already points to the current message' do
      before do
        conversation.update!(captain_welcome_source_message_id: message.id)
      end

      it 'returns true' do
        expect(claimer.claim?).to be(true)
      end
    end

    context 'when the marker already points to another message' do
      let!(:earlier_message) do
        create(
          :message,
          message_type: :incoming,
          sender: conversation.contact,
          account: account,
          inbox: inbox,
          conversation: conversation
        )
      end

      before do
        conversation.update!(captain_welcome_source_message_id: earlier_message.id)
      end

      it 'returns false' do
        expect(claimer.claim?).to be(false)
      end
    end

    context 'when an existing conversation has no marker and an earlier incoming contact message' do
      let!(:earlier_message) do
        create(
          :message,
          message_type: :incoming,
          sender: conversation.contact,
          account: account,
          inbox: inbox,
          conversation: conversation
        )
      end

      it 'claims the earlier source message and returns false for the current follow-up' do
        expect(claimer.claim?).to be(false)
        expect(conversation.reload.captain_welcome_source_message_id).to eq(earlier_message.id)
      end
    end

    context 'when another process claims the marker before the conditional update' do
      let!(:earlier_message) do
        create(
          :message,
          message_type: :incoming,
          sender: conversation.contact,
          account: account,
          inbox: inbox,
          conversation: conversation
        )
      end

      before do
        allow(Conversation).to receive(:where).and_call_original
        allow(Conversation).to receive(:where).with(id: conversation.id, captain_welcome_source_message_id: nil) do
          conversation.update!(captain_welcome_source_message_id: earlier_message.id)
          Conversation.where(id: conversation.id, captain_welcome_source_message_id: nil)
        end
      end

      it 'does not override the existing marker' do
        expect(claimer.claim?).to be(false)
        expect(conversation.reload.captain_welcome_source_message_id).to eq(earlier_message.id)
      end
    end

    context 'when the message is private' do
      let(:private_message) { true }

      it 'does not claim the marker' do
        expect(claimer.claim?).to be(false)
        expect(conversation.reload.captain_welcome_source_message_id).to be_nil
      end
    end

    context 'when the message is outgoing' do
      let(:message) do
        create(
          :message,
          message_type: :outgoing,
          account: account,
          inbox: inbox,
          conversation: conversation
        )
      end

      it 'does not claim the marker' do
        expect(claimer.claim?).to be(false)
        expect(conversation.reload.captain_welcome_source_message_id).to be_nil
      end
    end

    context 'when no AI agent is attached to the inbox' do
      before do
        AgentBotInbox.delete_all
      end

      it 'does not claim the marker' do
        expect(claimer.claim?).to be(false)
        expect(conversation.reload.captain_welcome_source_message_id).to be_nil
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Captain::Copilot::Policies::WelcomeMessagePolicy do
  subject(:policy) { described_class.new(message) }

  let(:account) { create(:account) }
  let(:inbox) { create(:inbox, account: account) }
  let(:conversation) { create(:conversation, account: account, inbox: inbox, additional_attributes: conversation_attributes) }
  let(:conversation_attributes) { {} }
  let(:message) do
    create(
      :message,
      message_type: :incoming,
      sender: create(:contact, account: account),
      account: account,
      inbox: inbox,
      conversation: conversation,
      private: private_message
    )
  end
  let(:private_message) { false }
  let(:greeting_config) { { 'enabled' => true } }
  let(:ai_agent) do
    AiAgent.create!(
      account: account,
      name: 'Jangkau Agent',
      agent_type: :single_agent,
      template_type: :jangkau,
      flow_data: {},
      display_flow_data: { 'greeting_config' => greeting_config }
    )
  end

  before do
    allow(Subscriptions::IncrementUsageService).to receive(:new).and_return(instance_double(Subscriptions::IncrementUsageService, perform: true))
    AgentBotInbox.create!(inbox: inbox, ai_agent: ai_agent, status: :inactive)
    conversation.update!(captain_welcome_source_message_id: message.id)
  end

  describe '#eligible?' do
    it 'returns true when greeting is enabled and the message is the claimed welcome source' do
      expect(policy).to be_eligible
    end

    context 'when the welcome source marker is missing' do
      before do
        conversation.update!(captain_welcome_source_message_id: nil)
      end

      it 'returns false' do
        expect(policy).not_to be_eligible
      end
    end

    context 'when the welcome source marker points to another message' do
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
        expect(policy).not_to be_eligible
      end
    end

    context 'when greeting is disabled' do
      let(:greeting_config) { { 'enabled' => false } }

      it 'returns false' do
        expect(policy).not_to be_eligible
      end
    end

    context 'when the conversation already has an AI reply' do
      before do
        Message.create!(
          account: account,
          inbox: inbox,
          conversation: conversation,
          message_type: :outgoing,
          sender_type: 'AiAgent',
          sender_id: ai_agent.id,
          content: 'Welcome!'
        )
      end

      it 'returns false' do
        expect(policy).not_to be_eligible
      end
    end

    context 'when the conversation is a group conversation' do
      let(:conversation_attributes) { { 'group_chat_id' => 'sales-group' } }

      it 'returns false' do
        expect(policy).not_to be_eligible
      end
    end

    context 'when the message is private' do
      let(:private_message) { true }

      it 'returns false' do
        expect(policy).not_to be_eligible
      end
    end

    context 'when no AI agent is attached to the inbox' do
      before do
        AgentBotInbox.delete_all
      end

      it 'returns false' do
        expect(policy).not_to be_eligible
      end
    end
  end
end

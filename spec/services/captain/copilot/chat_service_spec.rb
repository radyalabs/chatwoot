require 'rails_helper'

RSpec.describe Captain::Copilot::ChatService do
  subject(:service) { described_class.new(fixtures[:message]) }

  let(:fixtures) do
    message = instance_double(Message, content: 'Hello')
    attachments = instance_double(ActiveRecord::Associations::CollectionProxy)
    account = instance_double(Account, id: 1, locale: 'en')
    conversation = instance_double(Conversation, id: 42)
    inbox = instance_double(Inbox)
    ai_agent = instance_double(AiAgent, custom_agent?: false)
    usage = instance_double(SubscriptionUsage, increment_ai_responses: true)
    context = instance_double(
      Captain::Copilot::State::MessageContext,
      account: account,
      conversation: conversation,
      ai_agent: ai_agent,
      usage: usage,
      inbox: inbox
    )
    eligibility_guard = instance_double(
      Captain::Copilot::Guards::EligibilityGuard,
      check: Captain::Copilot::Guards::EligibilityGuard::Result.new(code: nil)
    )
    group_policy = instance_double(Captain::Copilot::Policies::GroupMentionPolicy, skip_reason: nil)
    state_handler = instance_double(Captain::Copilot::State::ConversationStateHandler, clear_pending_idle_conversation: true)
    assistant_response = instance_double(
      HTTParty::Response,
      success?: true,
      parsed_response: { 'response' => 'Hello from AI', 'attachments' => [] }
    )
    assistant_service = instance_double(Captain::Llm::AssistantChatService, perform: assistant_response)
    reply_sender = instance_double(Captain::Copilot::ReplySender, send_reply: true)

    {
      account: account,
      ai_agent: ai_agent,
      assistant_service: assistant_service,
      attachments: attachments,
      context: context,
      conversation: conversation,
      eligibility_guard: eligibility_guard,
      group_policy: group_policy,
      inbox: inbox,
      message: message,
      reply_sender: reply_sender,
      state_handler: state_handler,
      usage: usage
    }
  end

  before do
    allow(fixtures[:message]).to receive(:attachments).and_return(fixtures[:attachments])
    allow(fixtures[:attachments]).to receive(:includes).with(file_attachment: :blob).and_return([])
    allow(Captain::Copilot::State::MessageContext).to receive(:new).with(fixtures[:message]).and_return(fixtures[:context])
    allow(Captain::Copilot::Guards::EligibilityGuard).to receive(:new).and_return(fixtures[:eligibility_guard])
    allow(Captain::Copilot::Policies::GroupMentionPolicy).to receive(:new)
      .with(fixtures[:message], inbox: fixtures[:inbox]).and_return(fixtures[:group_policy])
    allow(Captain::Copilot::State::ConversationStateHandler)
      .to receive(:new).with(fixtures[:context]).and_return(fixtures[:state_handler])
    allow(Captain::Copilot::ReplySender)
      .to receive(:new).with(fixtures[:context], state_handler: fixtures[:state_handler]).and_return(fixtures[:reply_sender])
    allow(Captain::Llm::AssistantChatService).to receive(:new).and_return(fixtures[:assistant_service])
  end

  describe '#perform' do
    it 'generates a normal completion response and sends it through ReplySender' do
      service.perform

      expect(Captain::Llm::AssistantChatService).to have_received(:new).with(
        context: {
          message: fixtures[:message],
          conversation: fixtures[:conversation],
          ai_agent: fixtures[:ai_agent],
          account_id: fixtures[:account].id
        },
        attachments: [],
        intent: :completion
      )
      expect(fixtures[:usage]).to have_received(:increment_ai_responses)
      expect(fixtures[:reply_sender]).to have_received(:send_reply).with(
        {
          response: 'Hello from AI',
          is_handover: false,
          is_end_state: false,
          has_domain_change: false,
          attachments: []
        },
        additional_attributes: { message_type: 1, sender_type: 'AiAgent', attachments: [] }
      )
    end
  end
end

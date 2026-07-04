require 'rails_helper'

RSpec.describe Captain::Copilot::WelcomeMessageService do
  subject(:service) { described_class.new(fixtures[:message]) }

  let(:conversation_attributes) { {} }
  let(:greeting_images_sent) { true }
  let(:assistant_success) { true }
  let(:eligibility_result) { Captain::Copilot::EligibilityGuard::Result.new(code: nil) }
  let(:fixtures) do
    message = instance_double(Message, id: 7, content: 'Hello')
    attachments = instance_double(ActiveRecord::Associations::CollectionProxy)
    account = instance_double(Account, id: 1, locale: 'en')
    conversation = instance_double(Conversation, id: 42, additional_attributes: conversation_attributes, update!: true)
    ai_agent = instance_double(AiAgent, custom_agent?: false)
    usage = instance_double(SubscriptionUsage, increment_ai_responses: true)
    context = instance_double(
      Captain::Copilot::MessageContext,
      account: account,
      conversation: conversation,
      ai_agent: ai_agent,
      usage: usage
    )
    eligibility_guard = instance_double(Captain::Copilot::EligibilityGuard, check: eligibility_result)
    state_handler = instance_double(Captain::Copilot::ConversationStateHandler, clear_pending_idle_conversation: true)
    reply_sender = instance_double(Captain::Copilot::ReplySender, send_reply: true, send_failure: true)
    greeting_image_sender = instance_double(Captain::Copilot::GreetingImageSender, perform: greeting_images_sent)
    assistant_response = instance_double(
      HTTParty::Response,
      success?: assistant_success,
      parsed_response: { 'response' => 'Welcome!', 'attachments' => [] }
    )
    assistant_service = instance_double(Captain::Llm::AssistantChatService, perform: assistant_response)
    eligibility_logger = instance_double(Captain::Copilot::EligibilityGuardLogger, log: true)

    {
      account: account,
      ai_agent: ai_agent,
      assistant_service: assistant_service,
      attachments: attachments,
      context: context,
      conversation: conversation,
      eligibility_guard: eligibility_guard,
      eligibility_logger: eligibility_logger,
      greeting_image_sender: greeting_image_sender,
      message: message,
      reply_sender: reply_sender,
      state_handler: state_handler,
      usage: usage
    }
  end

  before do
    allow(fixtures[:message]).to receive(:attachments).and_return(fixtures[:attachments])
    allow(fixtures[:attachments]).to receive(:includes).with(file_attachment: :blob).and_return([])
    allow(Captain::Copilot::MessageContext).to receive(:new).with(fixtures[:message]).and_return(fixtures[:context])
    allow(Captain::Copilot::EligibilityGuard).to receive(:new).and_return(fixtures[:eligibility_guard])
    allow(Captain::Copilot::ConversationStateHandler)
      .to receive(:new).with(fixtures[:context]).and_return(fixtures[:state_handler])
    allow(Captain::Copilot::ReplySender)
      .to receive(:new).with(fixtures[:context], state_handler: fixtures[:state_handler]).and_return(fixtures[:reply_sender])
    allow(Captain::Copilot::GreetingImageSender)
      .to receive(:new).with(fixtures[:context]).and_return(fixtures[:greeting_image_sender])
    allow(Captain::Llm::AssistantChatService).to receive(:new).and_return(fixtures[:assistant_service])
    allow(Captain::Copilot::EligibilityGuardLogger).to receive(:new).and_return(fixtures[:eligibility_logger])
  end

  describe '#perform' do
    it 'calls the assistant with welcome intent and sends greeting images with the response as caption' do
      service.perform

      expect(Captain::Llm::AssistantChatService).to have_received(:new).with(
        context: {
          message: fixtures[:message],
          conversation: fixtures[:conversation],
          ai_agent: fixtures[:ai_agent],
          account_id: fixtures[:account].id
        },
        attachments: [],
        intent: :welcome
      )
      expect(fixtures[:usage]).to have_received(:increment_ai_responses)
      expect(fixtures[:conversation]).to have_received(:update!).with(
        additional_attributes: { 'last_debounced_processed_message_id' => 7 }
      )
      expect(fixtures[:greeting_image_sender]).to have_received(:perform).with(
        caption: 'Welcome!',
        additional_attributes: { 'welcome_source_message_id' => 7 }
      )
      expect(fixtures[:reply_sender]).not_to have_received(:send_reply)
    end

    context 'when no greeting image is sent' do
      let(:greeting_images_sent) { false }

      it 'falls back to a text reply' do
        service.perform

        expect(fixtures[:reply_sender]).to have_received(:send_reply).with(
          {
            response: 'Welcome!',
            is_handover: false,
            is_end_state: false,
            has_domain_change: false,
            attachments: []
          },
          additional_attributes: {
            message_type: 1,
            sender_type: 'AiAgent',
            attachments: [],
            additional_attributes: { 'welcome_source_message_id' => 7 }
          }
        )
      end
    end

    context 'when the conversation is a group conversation' do
      let(:conversation_attributes) { { 'group_chat_id' => 'sales-group' } }

      it 'skips welcome processing' do
        service.perform

        expect(Captain::Copilot::EligibilityGuard).not_to have_received(:new)
        expect(Captain::Llm::AssistantChatService).not_to have_received(:new)
      end
    end

    context 'when eligibility fails with a pre-check failure' do
      let(:eligibility_result) do
        Captain::Copilot::EligibilityGuard::Result.new(code: :pre_check_failure, failure_reason: 'Limit reached')
      end

      it 'logs and sends a failure reply' do
        service.perform

        expect(fixtures[:eligibility_logger]).to have_received(:log).with(eligibility_result)
        expect(fixtures[:reply_sender]).to have_received(:send_failure).with(
          'Limit reached',
          additional_attributes: { 'welcome_source_message_id' => 7 }
        )
        expect(Captain::Llm::AssistantChatService).not_to have_received(:new)
      end
    end

    context 'when the assistant request fails' do
      let(:assistant_success) { false }

      it 'sends a failure reply with welcome source metadata' do
        service.perform

        expect(fixtures[:reply_sender]).to have_received(:send_failure).with(
          I18n.t('conversations.bot.failure'),
          additional_attributes: { 'welcome_source_message_id' => 7 }
        )
      end
    end
  end
end

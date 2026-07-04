require 'rails_helper'

RSpec.describe Captain::Copilot::ReplySender do
  subject(:sender) { described_class.new(context, state_handler: state_handler) }

  let(:conversation) { instance_double(Conversation, id: 42) }
  let(:context) { instance_double(Captain::Copilot::MessageContext, conversation: conversation) }
  let(:state_handler) do
    instance_double(
      Captain::Copilot::ConversationStateHandler,
      process_handover: 'handover content',
      process_end_state: true,
      process_conversion: true
    )
  end
  let(:dispatcher) { instance_double(Captain::Copilot::ReplyDispatcher, perform: true) }

  before do
    allow(Captain::Copilot::ReplyDispatcher).to receive(:new).with(context).and_return(dispatcher)
    allow(Rails.logger).to receive(:info)
    allow(Rails.logger).to receive(:warn)
    allow(Rails.logger).to receive(:error)
  end

  describe '#send_reply' do
    it 'processes normal reply state and dispatches the response' do
      response = {
        response: 'Hello',
        is_handover: false,
        is_failure: false,
        has_domain_change: false
      }

      sender.send_reply(
        response,
        additional_attributes: { message_type: 1, sender_type: 'AiAgent', reservation_details: { id: 1 } }
      )

      expect(state_handler).to have_received(:process_end_state).with(response)
      expect(state_handler).to have_received(:process_conversion).with(response)
      expect(dispatcher).to have_received(:perform).with(
        content: 'Hello',
        additional_attributes: { message_type: 1, sender_type: 'AiAgent' }
      )
    end

    it 'processes handover content and skips end-state scheduling' do
      response = {
        response: 'Please hand over',
        is_handover: true,
        is_failure: false,
        has_domain_change: false
      }

      sender.send_reply(response, additional_attributes: { message_type: 1 })

      expect(state_handler).to have_received(:process_handover).with('Please hand over')
      expect(state_handler).not_to have_received(:process_end_state)
      expect(state_handler).to have_received(:process_conversion).with(response)
      expect(dispatcher).to have_received(:perform).with(
        content: 'handover content',
        additional_attributes: { message_type: 1 }
      )
    end

    it 'logs save failures without raising' do
      response = {
        response: 'Hello',
        is_handover: false,
        is_failure: false,
        has_domain_change: false
      }

      allow(dispatcher).to receive(:perform).and_raise(StandardError)

      expect { sender.send_reply(response) }.not_to raise_error
      expect(Rails.logger).to have_received(:error).with(
        '[Captain::Copilot::ReplySender] ai_reply_save_failed | conversation_id=42 | error_class=StandardError'
      )
    end
  end

  describe '#send_failure' do
    it 'sends a failure response without scheduling end-state processing' do
      sender.send_failure('Limit reached')

      expect(state_handler).not_to have_received(:process_end_state)
      expect(state_handler).to have_received(:process_conversion).with(
        response: 'Limit reached',
        is_handover: false,
        is_end_state: false,
        has_domain_change: false,
        is_failure: true
      )
      expect(dispatcher).to have_received(:perform).with(
        content: 'Limit reached',
        additional_attributes: { message_type: 3 }
      )
    end

    it 'merges additional attributes into the failure response' do
      sender.send_failure('Limit reached', additional_attributes: { 'welcome_source_message_id' => 7 })

      expect(dispatcher).to have_received(:perform).with(
        content: 'Limit reached',
        additional_attributes: { :message_type => 3, 'welcome_source_message_id' => 7 }
      )
    end
  end
end

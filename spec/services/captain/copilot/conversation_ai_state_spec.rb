require 'rails_helper'

RSpec.describe Captain::Copilot::ConversationAiState do
  subject(:state) { described_class.new(conversation) }

  let(:messages_association) { instance_double('MessagesAssociation') }
  let(:incoming_scope) { instance_double('IncomingScope') }
  let(:conversation) { instance_double('Conversation', messages: messages_association, additional_attributes: additional_attributes) }
  let(:additional_attributes) { {} }

  describe '#processing_boundary_message_id' do
    context 'when watermark is newer than last ai reply' do
      let(:additional_attributes) { { 'last_debounced_processed_message_id' => 42 } }

      it 'uses watermark as boundary' do
        allow(state).to receive(:last_ai_reply).and_return(instance_double('Message', id: 30))

        expect(state.processing_boundary_message_id).to eq(42)
      end
    end

    context 'when no watermark exists' do
      it 'falls back to last ai reply id' do
        allow(state).to receive(:last_ai_reply).and_return(instance_double('Message', id: 30))

        expect(state.processing_boundary_message_id).to eq(30)
      end
    end
  end

  describe '#incoming_contact_messages_since_processing_boundary' do
    let(:additional_attributes) { { 'last_debounced_processed_message_id' => 42 } }

    it 'filters incoming contact messages by boundary id' do
      filtered_scope = instance_double('FilteredScope')

      allow(messages_association).to receive(:incoming).and_return(incoming_scope)
      allow(incoming_scope).to receive(:where).with(sender_type: 'Contact', private: false).and_return(incoming_scope)
      allow(state).to receive(:last_ai_reply).and_return(nil)
      allow(incoming_scope).to receive(:where).with('id > ?', 42).and_return(filtered_scope)

      expect(state.send(:incoming_contact_messages_since_processing_boundary)).to eq(filtered_scope)
    end
  end
end

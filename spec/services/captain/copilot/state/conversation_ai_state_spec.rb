require 'rails_helper'

RSpec.describe Captain::Copilot::State::ConversationAiState do
  subject(:state) { described_class.new(conversation) }

  let(:messages_association) { object_double(Message.all) }
  let(:incoming_scope) { object_double(Message.all) }
  let(:ai_reply_scope) { object_double(Message.all) }
  let(:ordered_ai_reply_scope) { object_double(Message.all) }
  let(:conversation) { instance_double(Conversation, messages: messages_association, additional_attributes: additional_attributes) }
  let(:additional_attributes) { {} }

  before do
    allow(messages_association).to receive(:where).with(sender_type: 'AiAgent').and_return(ai_reply_scope)
    allow(ai_reply_scope).to receive(:order).with(created_at: :desc, id: :desc).and_return(ordered_ai_reply_scope)
    allow(ordered_ai_reply_scope).to receive(:first).and_return(instance_double(Message, id: 30))
  end

  describe '#processing_boundary_message_id' do
    context 'when watermark is newer than last ai reply' do
      let(:additional_attributes) { { 'last_debounced_processed_message_id' => 42 } }

      it 'uses watermark as boundary' do
        expect(state.processing_boundary_message_id).to eq(42)
      end
    end

    context 'when watermark is older than last ai reply' do
      let(:additional_attributes) { { 'last_debounced_processed_message_id' => 12 } }

      it 'uses watermark so direct welcome replies do not hide follow-up messages' do
        expect(state.processing_boundary_message_id).to eq(12)
      end
    end

    context 'when no watermark exists' do
      it 'falls back to last ai reply id' do
        expect(state.processing_boundary_message_id).to eq(30)
      end
    end
  end

  describe '#incoming_contact_messages_since_processing_boundary' do
    let(:additional_attributes) { { 'last_debounced_processed_message_id' => 42 } }

    it 'filters incoming contact messages by boundary id' do
      filtered_scope = object_double(Message.all)

      allow(messages_association).to receive(:incoming).and_return(incoming_scope)
      allow(incoming_scope).to receive(:where).with(sender_type: 'Contact', private: false).and_return(incoming_scope)
      allow(incoming_scope).to receive(:where).with('id > ?', 42).and_return(filtered_scope)

      expect(state.send(:incoming_contact_messages_since_processing_boundary)).to eq(filtered_scope)
    end
  end
end

require 'rails_helper'

RSpec.describe Captain::Copilot::ProcessDebouncedConversationJob do
  subject(:job) { described_class.new }

  let(:conversation_id) { 123 }
  let(:conversation) { instance_double('Conversation', id: conversation_id, messages: messages_relation) }
  let(:messages_relation) { instance_double('MessagesAssociation') }
  let(:incoming_relation) { instance_double('IncomingRelation') }
  let(:state) { instance_double(Captain::Copilot::ConversationAiState) }
  let(:first_in_burst) { instance_double('Message', created_at: Time.current) }

  before do
    allow(Conversation).to receive(:find_by).with(id: conversation_id).and_return(conversation)
    allow(Captain::Copilot::ConversationAiState).to receive(:new).with(conversation).and_return(state)
    allow(messages_relation).to receive(:incoming).and_return(incoming_relation)
  end

  describe '#perform' do
    it 'returns early when a newer message supersedes scheduled message' do
      scheduled_message = instance_double('Message', id: 10)
      latest_message = instance_double('Message', id: 20)

      allow(state).to receive(:latest_incoming_contact_message).and_return(latest_message)
      allow(state).to receive(:first_unprocessed_incoming_message).and_return(first_in_burst)
      allow(incoming_relation).to receive(:find_by).with(id: 10, sender_type: 'Contact', private: false).and_return(scheduled_message)
      allow(job).to receive(:max_wait_seconds).and_return(60)

      expect(Captain::Copilot::ChatServiceJob).not_to receive(:perform_later)

      job.perform(conversation_id, 10)
    end

    it 'invokes ChatServiceJob with combined content in order for multi-message burst' do
      latest_message = instance_double('Message', id: 30)
      scheduled_message = latest_message
      first_message = instance_double('Message', content: 'Hello')
      second_message = instance_double('Message', content: 'Need help')
      third_message = instance_double('Message', content: 'with payment')

      allow(state).to receive(:latest_incoming_contact_message).and_return(latest_message)
      allow(state).to receive(:first_unprocessed_incoming_message).and_return(first_in_burst)
      allow(incoming_relation).to receive(:find_by).with(id: 30, sender_type: 'Contact', private: false).and_return(scheduled_message)
      allow(job).to receive(:burst_messages).and_return([first_message, second_message, third_message])
      allow(job).to receive(:collect_attachments).and_return([])

      expect(Captain::Copilot::ChatServiceJob).to receive(:perform_later).with(
        30,
        combined_question: "Hello\nNeed help\nwith payment",
        attachments: []
      )

      job.perform(conversation_id, 30)
    end

    it 'invokes latest message when max_wait is reached by first burst message' do
      scheduled_message = instance_double('Message', id: 40)
      latest_message = instance_double('Message', id: 41)
      old_first = instance_double('Message', created_at: 2.minutes.ago)
      first_message = instance_double('Message', content: 'first')
      second_message = instance_double('Message', content: 'latest')

      allow(state).to receive(:latest_incoming_contact_message).and_return(latest_message)
      allow(state).to receive(:first_unprocessed_incoming_message).and_return(old_first)
      allow(incoming_relation).to receive(:find_by).with(id: 40, sender_type: 'Contact', private: false).and_return(scheduled_message)
      allow(job).to receive(:max_wait_seconds).and_return(30)
      allow(job).to receive(:burst_messages).and_return([first_message, second_message])
      allow(job).to receive(:collect_attachments).and_return([])

      expect(Captain::Copilot::ChatServiceJob).to receive(:perform_later).with(
        41,
        combined_question: "first\nlatest",
        attachments: []
      )

      job.perform(conversation_id, 40)
    end
  end

  describe '#collect_attachments' do
    it 'collects attachment payload from all messages in burst' do
      blob1 = instance_double('Blob', key: 'k1', content_type: 'image/png', filename: 'a.png')
      blob2 = instance_double('Blob', key: 'k2', content_type: 'image/jpeg', filename: 'b.jpg')
      file1 = instance_double('AttachedFile', attached?: true, key: blob1.key, content_type: blob1.content_type, filename: blob1.filename)
      file2 = instance_double('AttachedFile', attached?: true, key: blob2.key, content_type: blob2.content_type, filename: blob2.filename)
      attachment1 = instance_double('Attachment', file: file1, download_url: 'https://example.com/a')
      attachment2 = instance_double('Attachment', file: file2, download_url: 'https://example.com/b')
      message1 = instance_double('Message', attachments: [attachment1])
      message2 = instance_double('Message', attachments: [attachment2])

      payload = job.send(:collect_attachments, [message1, message2])

      expect(payload).to eq([
                              { key: 'k1', file_type: 'image/png', filename: 'a.png', url: 'https://example.com/a' },
                              { key: 'k2', file_type: 'image/jpeg', filename: 'b.jpg', url: 'https://example.com/b' }
                            ])
    end
  end
end

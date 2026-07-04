require 'rails_helper'

RSpec.describe Captain::Copilot::WelcomeMessageJob do
  subject(:job) { described_class.new }

  let(:message_id) { 123 }
  let(:message) { instance_double(Message, conversation_id: 42) }
  let(:messages_relation) { instance_double(ActiveRecord::Relation) }
  let(:policy) { instance_double(Captain::Copilot::WelcomeMessagePolicy) }
  let(:eligible) { true }
  let(:service) { instance_double(Captain::Copilot::WelcomeMessageService, perform: true) }
  let(:lock) { instance_double(Captain::Copilot::AiInvocationLock) }
  let(:lock_states) { [] }

  before do
    inside_lock = false

    allow(Message).to receive(:includes).with(attachments: { file_attachment: :blob }).and_return(messages_relation)
    allow(messages_relation).to receive(:find_by).with(id: message_id).and_return(message)
    allow(Captain::Copilot::WelcomeMessagePolicy).to receive(:new).with(message).and_return(policy)
    allow(Captain::Copilot::WelcomeMessageService).to receive(:new).with(message).and_return(service)
    allow(Captain::Copilot::AiInvocationLock).to receive(:new).with(42).and_return(lock)
    allow(lock).to receive(:with_lock) do |&block|
      inside_lock = true
      block.call
    ensure
      inside_lock = false
    end
    allow(policy).to receive(:eligible?) do
      lock_states << inside_lock
      eligible
    end
  end

  describe '#perform' do
    it 're-checks welcome eligibility before invoking the service' do
      job.perform(message_id)

      expect(policy).to have_received(:eligible?)
      expect(lock_states).to eq([true])
      expect(Captain::Copilot::WelcomeMessageService).to have_received(:new).with(message)
      expect(service).to have_received(:perform)
    end

    context 'when the message no longer exists' do
      let(:message) { nil }

      it 'does not check policy or invoke the service' do
        job.perform(message_id)

        expect(Captain::Copilot::AiInvocationLock).not_to have_received(:new)
        expect(Captain::Copilot::WelcomeMessagePolicy).not_to have_received(:new)
        expect(Captain::Copilot::WelcomeMessageService).not_to have_received(:new)
      end
    end

    context 'when the message is no longer welcome-eligible' do
      let(:eligible) { false }

      it 'does not invoke the service' do
        job.perform(message_id)

        expect(policy).to have_received(:eligible?)
        expect(lock_states).to eq([true])
        expect(Captain::Copilot::WelcomeMessageService).not_to have_received(:new)
      end
    end
  end
end

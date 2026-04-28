require 'rails_helper'

RSpec.describe WhatsappUnofficial::IncomingMessageServiceHelpers do
  subject(:helper) { helper_class.new(params) }

  let(:helper_class) do
    Class.new do
      include WhatsappUnofficial::IncomingMessageServiceHelpers

      attr_reader :params

      def initialize(params)
        @params = params
      end
    end
  end

  describe '#gowa_reply_content_attributes' do
    context 'when payload has contextInfo stanzaId' do
      let(:params) do
        {
          'payload' => {
            'id' => 'msg-1',
            'body' => 'hi',
            'contextInfo' => { 'stanzaId' => 'msg-0' }
          }
        }
      end

      it 'extracts in_reply_to_external_id' do
        attrs = helper.gowa_reply_content_attributes
        expect(attrs[:in_reply_to_external_id]).to eq('msg-0')
        expect(attrs[:gowa_reply]).to include(raw_in_reply_to_external_id: 'msg-0')
      end
    end

    context 'when payload has top-level quotedMsgId' do
      let(:params) do
        {
          'payload' => {
            'id' => 'msg-1',
            'quotedMsgId' => 'msg-0'
          }
        }
      end

      it 'extracts in_reply_to_external_id' do
        attrs = helper.gowa_reply_content_attributes
        expect(attrs[:in_reply_to_external_id]).to eq('msg-0')
        expect(attrs[:gowa_reply]).to include(raw_in_reply_to_external_id: 'msg-0')
      end
    end

    context 'when payload has quotedMessage conversation text' do
      let(:params) do
        {
          'payload' => {
            'id' => 'msg-1',
            'contextInfo' => {
              'quotedMessage' => {
                'conversation' => 'quoted hello'
              }
            }
          }
        }
      end

      it 'extracts quoted text into gowa_reply' do
        attrs = helper.gowa_reply_content_attributes
        expect(attrs[:in_reply_to_external_id]).to be_nil
        expect(attrs[:gowa_reply]).to include(quoted_text: 'quoted hello')
      end
    end

    context 'when payload has no reply-related fields' do
      let(:params) do
        {
          'payload' => {
            'id' => 'msg-1',
            'body' => 'normal message'
          }
        }
      end

      it 'returns empty hash' do
        expect(helper.gowa_reply_content_attributes).to eq({})
      end
    end
  end
end

require 'rails_helper'

RSpec.describe Captain::Llm::JangkauEndpointPolicy do
  describe '#endpoint' do
    it 'defaults to completion endpoint' do
      expect(described_class.new.endpoint).to eq(described_class::COMPLETION_ENDPOINT)
    end

    it 'uses completion endpoint for completion intent' do
      expect(described_class.new(intent: :completion).endpoint).to eq(described_class::COMPLETION_ENDPOINT)
    end

    it 'uses welcome endpoint for welcome intent' do
      expect(described_class.new(intent: :welcome).endpoint).to eq(described_class::WELCOME_ENDPOINT)
    end

    it 'accepts string intents' do
      expect(described_class.new(intent: 'welcome').endpoint).to eq(described_class::WELCOME_ENDPOINT)
    end

    it 'raises for unsupported intents' do
      expect { described_class.new(intent: :unknown).endpoint }.to raise_error(ArgumentError, 'Unsupported Jangkau intent: unknown')
    end
  end
end

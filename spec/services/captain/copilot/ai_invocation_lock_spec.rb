require 'rails_helper'

RSpec.describe Captain::Copilot::AiInvocationLock do
  describe '#with_lock' do
    let(:connection) { instance_double(ActiveRecord::ConnectionAdapters::AbstractAdapter) }
    let(:executed_sql) { [] }

    before do
      allow(ActiveRecord::Base).to receive(:connection).and_return(connection)
      allow(connection).to receive(:execute) { |sql| executed_sql << sql }
    end

    it 'locks and unlocks around the block' do
      result = described_class.new(42).with_lock do
        executed_sql << 'yielded'
        :ok
      end

      expect(result).to eq(:ok)
      expect(executed_sql).to eq(
        [
          'SELECT pg_advisory_lock(10203, 42)',
          'yielded',
          'SELECT pg_advisory_unlock(10203, 42)'
        ]
      )
    end

    it 'unlocks when the block raises' do
      expect do
        described_class.new(42).with_lock { raise StandardError, 'boom' }
      end.to raise_error(StandardError, 'boom')

      expect(executed_sql).to eq(
        [
          'SELECT pg_advisory_lock(10203, 42)',
          'SELECT pg_advisory_unlock(10203, 42)'
        ]
      )
    end
  end
end

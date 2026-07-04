require 'rails_helper'

RSpec.describe Captain::Llm::Clients::JangkauApiClient do
  describe '#post_with_welcome_fallback' do
    let(:client) { described_class.new }
    let(:headers) { { 'Content-Type' => 'application/json', 'X-API-Key' => 'test' } }
    let(:body) { { question: 'hello' } }

    it 'uses HTTParty class-level post for request execution' do
      response = instance_double(HTTParty::Response, success?: true, parsed_response: { 'answer' => 'ok' }, code: 200)

      allow(described_class).to receive(:post).and_return(response)

      result = client.post_with_welcome_fallback(
        endpoint: Captain::Llm::Policies::JangkauEndpointPolicy::COMPLETION_ENDPOINT,
        body: body,
        headers: headers
      )

      expect(described_class).to have_received(:post).with(
        Captain::Llm::Policies::JangkauEndpointPolicy::COMPLETION_ENDPOINT,
        body: body.to_json,
        headers: headers
      ).once
      expect(result).to eq(response)
    end

    it 'falls back to completion endpoint when welcome endpoint returns failure' do
      welcome_response = instance_double(HTTParty::Response, success?: false, parsed_response: nil, code: 500)
      fallback_response = instance_double(HTTParty::Response, success?: true, parsed_response: { 'answer' => 'ok' }, code: 200)

      allow(described_class).to receive(:post)
        .with(Captain::Llm::Policies::JangkauEndpointPolicy::WELCOME_ENDPOINT, body: body.to_json, headers: headers)
        .and_return(welcome_response)
      allow(described_class).to receive(:post)
        .with(Captain::Llm::Policies::JangkauEndpointPolicy::COMPLETION_ENDPOINT, body: body.to_json, headers: headers)
        .and_return(fallback_response)

      result = client.post_with_welcome_fallback(
        endpoint: Captain::Llm::Policies::JangkauEndpointPolicy::WELCOME_ENDPOINT,
        body: body,
        headers: headers
      )

      expect(result).to eq(fallback_response)
      expect(described_class).to have_received(:post).with(
        Captain::Llm::Policies::JangkauEndpointPolicy::WELCOME_ENDPOINT,
        body: body.to_json,
        headers: headers
      ).once
      expect(described_class).to have_received(:post).with(
        Captain::Llm::Policies::JangkauEndpointPolicy::COMPLETION_ENDPOINT,
        body: body.to_json,
        headers: headers
      ).once
    end

    it 'does not fallback when welcome endpoint succeeds with parsed response' do
      welcome_response = instance_double(HTTParty::Response, success?: true, parsed_response: { 'answer' => 'ok' }, code: 200)

      allow(described_class).to receive(:post).and_return(welcome_response)

      result = client.post_with_welcome_fallback(
        endpoint: Captain::Llm::Policies::JangkauEndpointPolicy::WELCOME_ENDPOINT,
        body: body,
        headers: headers
      )

      expect(result).to eq(welcome_response)
      expect(described_class).to have_received(:post).with(
        Captain::Llm::Policies::JangkauEndpointPolicy::WELCOME_ENDPOINT,
        body: body.to_json,
        headers: headers
      ).once
      expect(described_class).not_to have_received(:post).with(
        Captain::Llm::Policies::JangkauEndpointPolicy::COMPLETION_ENDPOINT,
        body: body.to_json,
        headers: headers
      )
    end
  end
end

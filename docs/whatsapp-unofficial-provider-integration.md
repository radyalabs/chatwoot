# WhatsApp Unofficial Provider Integration Guide

This document describes how to integrate a new WhatsApp service provider (e.g., WAHA, GOWA) into the WhatsApp Unofficial channel.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Controller Layer                          │
│  Api::V1::Accounts::InboxesController                           │
│  (whatsapp_qr, whatsapp_status, whatsapp_rescan)                │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                         Model Layer                              │
│  Channel::WhatsappUnofficial                                     │
│  - Delegates to services for business logic                      │
│  - Delegates to adapter for provider-specific operations         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          │                │                │
          ▼                ▼                ▼
┌─────────────────┐ ┌─────────────┐ ┌─────────────────┐
│    Services     │ │   Adapter   │ │    Concerns     │
│ - QrCodeService │ │   Factory   │ │ - Cacheable     │
│ - SessionStatus │ │      │      │ │ - PhoneNorm...  │
│ - CallbackProc. │ │      ▼      │ └─────────────────┘
│ - PhoneValid... │ │ ┌─────────┐ │
│ - BroadcastSvc  │ │ │ Adapter │ │
└─────────────────┘ │ └────┬────┘ │
                    └──────┼──────┘
                           │
          ┌────────────────┴────────────────┐
          ▼                                 ▼
┌─────────────────────┐          ┌─────────────────────┐
│    WahaAdapter      │          │    GowaAdapter      │
│ - Uses WahaService  │          │ - Uses GowaService  │
└─────────────────────┘          └─────────────────────┘
          │                                 │
          ▼                                 ▼
┌─────────────────────┐          ┌─────────────────────┐
│  Waha::WahaService  │          │  Gowa::GowaService  │
│  (HTTP client)      │          │  (HTTP client)      │
└─────────────────────┘          └─────────────────────┘
```

## Provider Responsibilities

A WhatsApp provider must support these core operations:

| Operation | Description |
|-----------|-------------|
| **Create Device** | Register a new device/session slot |
| **Get QR Code** | Retrieve QR code for WhatsApp pairing |
| **Get Session Status** | Check if session is connected/logged in |
| **Logout Session** | Disconnect the WhatsApp session |
| **Delete Device** | Remove the device slot entirely |

## Adding a New Provider

### Step 1: Create the HTTP Service

Create a service class that handles HTTP communication with the provider's API.

**Location:** `app/services/{provider_name}/{provider_name}_service.rb`

```ruby
# app/services/acme/acme_service.rb
class Acme::AcmeService
  API_BASE = ENV.fetch('ACME_API_URL', nil)

  def initialize(api_url: nil)
    @api_url = api_url || API_BASE
  end

  def create_device(device_id: nil)
    post('/devices', body: { device_id: device_id })
  end

  def get_qr_login(device_id:)
    get("/devices/#{device_id}/qr")
  end

  def get_device_status(device_id:)
    get("/devices/#{device_id}/status")
  end

  def logout_device(device_id:)
    post("/devices/#{device_id}/logout")
  end

  def delete_device(device_id:)
    delete("/devices/#{device_id}")
  end

  def configured?
    @api_url.present?
  end

  private

  def get(path, extra_headers: {})
    # Implement HTTP GET with authentication
  end

  def post(path, body: {}, extra_headers: {})
    # Implement HTTP POST with authentication
  end

  def delete(path, extra_headers: {})
    # Implement HTTP DELETE with authentication
  end

  def auth_headers
    # Return provider-specific auth headers
  end

  def handle_response(response, action)
    if response.success?
      Rails.logger.info "[Acme::AcmeService] #{action} succeeded"
      response.parsed_response
    else
      error_message = "#{action} failed: #{response.code} - #{response.body}"
      Rails.logger.error "[Acme::AcmeService] #{error_message}"
      raise StandardError, error_message
    end
  end
end
```

### Step 2: Create the Adapter

Create an adapter that implements the provider interface and normalizes responses.

**Location:** `app/adapters/whatsapp_unofficial/{provider_name}_adapter.rb`

```ruby
# app/adapters/whatsapp_unofficial/acme_adapter.rb
module WhatsappUnofficial
  class AcmeAdapter < BaseAdapter
    # Returns: { qr_data: String, qr_type: :base64 | :url } or nil
    # Returns :already_logged_in symbol if session is already connected
    def get_qr_code
      return nil unless channel.device_id.present?

      result = acme_service.get_qr_login(device_id: channel.device_id)
      qr_data = result.dig('qr_code') || result.dig('qr_link')
      qr_type = result.dig('qr_link') ? :url : :base64

      { qr_data: qr_data, qr_type: qr_type }
    rescue StandardError => e
      if e.message.include?('ALREADY_LOGGED_IN')
        :already_logged_in
      else
        log_error "Failed to get QR code: #{e.message}"
        nil
      end
    end

    # Returns: { connected: Boolean, status: String }
    def get_session_status
      return { connected: false, status: 'not_logged_in' } unless channel.device_id.present?

      result = acme_service.get_device_status(device_id: channel.device_id)
      connected = result.dig('is_connected') || false

      { connected: connected, status: connected ? 'logged_in' : 'not_logged_in' }
    rescue StandardError => e
      log_error "Failed to get session status: #{e.message}"
      { connected: false, status: 'error' }
    end

    # Creates device and stores credentials
    # Returns: { device_id: String }
    def create_device(webhook_url:)
      raise 'Provider not configured' unless configured?

      result = acme_service.create_device(device_id: channel.phone_number)
      device_id = result.dig('device_id')

      channel.update!(device_id: device_id)
      { device_id: device_id }
    end

    def initialize_session
      nil # Return nil if not needed
    end

    def logout_session
      return nil unless channel.device_id.present?
      acme_service.logout_device(device_id: channel.device_id)
    rescue StandardError => e
      log_error "Failed to logout: #{e.message}"
      nil
    end

    def delete_device
      return nil unless channel.device_id.present?
      acme_service.delete_device(device_id: channel.device_id)
      channel.update!(device_id: nil)
    rescue StandardError => e
      log_warn "Delete device failed: #{e.message}"
      nil
    end

    def webhook_url_for(phone_number)
      "#{base_url}/webhooks/acme"
    end

    def restart_session
      # Implement provider-specific restart logic
    end

    protected

    def configured?
      ENV['ACME_API_URL'].present?
    end

    private

    def acme_service
      @acme_service ||= Acme::AcmeService.new
    end
  end
end
```

### Step 3: Register the Provider

Update the adapter factory to recognize the new provider.

**File:** `app/adapters/whatsapp_unofficial/adapter_factory.rb`

```ruby
module WhatsappUnofficial
  class AdapterFactory
    ADAPTERS = {
      'waha' => WahaAdapter,
      'gowa' => GowaAdapter,
      'acme' => AcmeAdapter  # Add new provider
    }.freeze

    def self.for(channel)
      provider = channel.effective_provider
      adapter_class = ADAPTERS[provider]
      raise "Unknown provider: #{provider}" unless adapter_class
      adapter_class.new(channel)
    end

    def self.default_provider
      return 'acme' if ENV['ACME_API_URL'].present?
      return 'gowa' if ENV['GOWA_API_URL'].present?
      'waha'
    end
  end
end
```

### Step 4: Update Model Constants

**File:** `app/models/channel/whatsapp_unofficial.rb`

```ruby
PROVIDERS = %w[waha gowa acme].freeze
```

### Step 5: Add Cleanup Logic

**File:** `app/models/channel/whatsapp_unofficial.rb`

```ruby
def cleanup_provider_device
  # ...existing code...
  cleanup_acme_device if effective_provider == 'acme' && device_id.present?
end

def cleanup_acme_device
  Rails.logger.info "Cleaning up ACME device: #{device_id}"
  safe_adapter_call { adapter.logout_session }
  safe_adapter_call { adapter.delete_device }
end
```

### Step 6: Environment Variables

```bash
# Required
ACME_API_URL=https://your-acme-instance.com

# Authentication (choose based on provider)
ACME_API_KEY=your_api_key
# OR
ACME_USERNAME=your_username
ACME_PASSWORD=your_password

# Optional
ACME_WEBHOOK_SECRET=your_webhook_signing_secret
```

## Adapter Interface Contract

All adapters must inherit from `BaseAdapter` and implement:

| Method | Return Type | Description |
|--------|-------------|-------------|
| `get_qr_code` | `Hash`, `:already_logged_in`, or `nil` | Returns `{ qr_data:, qr_type: }` |
| `get_session_status` | `Hash` | Returns `{ connected: Boolean, status: String }` |
| `create_device(webhook_url:)` | `Hash` | Returns `{ device_id: String }` |
| `initialize_session` | `Hash` or `nil` | Optional post-creation setup |
| `logout_session` | `Hash` or `nil` | Disconnects the session |
| `delete_device` | `Hash` or `nil` | Removes the device |
| `webhook_url_for(phone_number)` | `String` | Returns webhook URL |
| `restart_session` | `Hash` | Handles QR rescan flow |
| `configured?` | `Boolean` | Checks provider configuration |

### QR Type Values

- `:base64` - QR code as base64-encoded PNG
- `:url` - Direct URL to QR code image

## Service Layer

Business logic lives in services, not the model:

| Service | Responsibility |
|---------|----------------|
| `QrCodeService` | QR retrieval with validation |
| `SessionStatusService` | Status checking with state transitions |
| `CallbackProcessor` | Webhook callback routing |
| `PhoneValidationService` | Phone validation with locking |
| `BroadcastService` | ActionCable event broadcasting |

## Provider Comparison

| Aspect | WAHA | GOWA |
|--------|------|------|
| Auth | Bearer token + X-API-Key | HTTP Basic Auth |
| Device ID Field | `token` | `device_id` |
| QR Format | base64 | URL |
| Webhook | `/webhooks/waha/{phone}` | `/webhooks/gowa` |

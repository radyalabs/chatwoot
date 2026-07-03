# BaseJangkauService Refactor Plan

## Goal

- Keep behavior unchanged while reducing overload in `Captain::Llm::BaseJangkauService`.
- Make `BaseJangkauService` a thin orchestrator.
- Move channel-specific/domain-specific logic (especially WhatsApp reply context) out of the base service.

## Current Issues

- Mixed responsibilities in one class:
  - Endpoint policy (`welcome` vs `completion`)
  - HTTP transport + fallback handling
  - Request payload construction
  - Attachment data access + formatting
  - WhatsApp-specific reply-context enrichment (`gowa_reply`, `in_reply_to_external_id`)
- Tight coupling to other domains (`Captain::Copilot::ConversationAiState`) from an LLM base service.

## Non-Goals

- No API contract changes for callers.
- No behavior redesign for welcome/completion flow.
- No test suite expansion unless explicitly requested.

## Constraints

- Preserve initializer + `perform` contract used by `Captain::Llm::AssistantChatService`.
- Keep payload shape and endpoint fallback behavior exactly the same.
- Prefer small PR-sized refactors with isolated concerns.

## Proposed Architecture

`BaseJangkauService` stays as orchestrator and delegates to collaborators:

- `Captain::Llm::JangkauEndpointPolicy`
  - Decide target endpoint (`/v2/chat/welcome/` or `/v2/chat/completion/`).
- `Captain::Llm::JangkauApiClient`
  - Execute HTTP request, apply timeout/headers, handle welcome fallback.
- `Captain::Llm::JangkauRequestBuilder`
  - Build `question`, `attachments`, and `overrideConfig` payload.
- `Captain::Llm::WhatsappReplyContextEnricher`
  - Handle reply-context extraction and prompt enrichment for WhatsApp unofficial messages.
- `Captain::Llm::AttachmentPayloadBuilder`
  - Build attachment payload from preview attachments or message attachments.

## Implementation Steps

### PR-1: Extract endpoint policy + API client

- Add `JangkauEndpointPolicy` for first-message + greeting decision.
- Add `JangkauApiClient` for request execution and welcome fallback.
- Update `BaseJangkauService` to delegate call flow to both classes.

Acceptance:

- Same endpoint selected under same conditions.
- Welcome fallback still triggers on non-success or blank response.

### PR-2: Extract request builder

- Add `JangkauRequestBuilder` for payload and config building.
- Move `extract_message_data` ownership to builder input flow.
- Keep payload keys and values unchanged.

Acceptance:

- `request_body` JSON output remains equivalent for existing inputs.

### PR-3: Extract WhatsApp reply context enricher

- Add `WhatsappReplyContextEnricher` containing:
  - reply-context detection
  - replied message lookup
  - fallback to quoted text
  - enriched question composition
- Remove WhatsApp-specific methods from `BaseJangkauService`.

Acceptance:

- Prompts are enriched exactly when current conditions are met.
- Non-WhatsApp messages remain unaffected.

### PR-4: Extract attachment payload builder

- Add `AttachmentPayloadBuilder` for attachment lookup and serialization.
- Keep precedence: `preview_attachments` first, then message attachments.

Acceptance:

- Attachment payload shape remains: `key`, `file_type`, `filename`, `url`.

### PR-5: Logging/error consistency cleanup (optional final pass)

- Normalize log prefix usage across new collaborators.
- Keep error surface compatible while reducing sensitive exposure where safe.

Acceptance:

- Existing observability remains usable.
- No new noisy logs.

## Verification Checklist

- Incoming first message + greeting enabled hits `/v2/chat/welcome/`.
- Welcome failure/blank response falls back to `/v2/chat/completion/`.
- Normal completion flow still works.
- WhatsApp unofficial reply with `in_reply_to`/`in_reply_to_external_id`/`gowa_reply.quoted_text` still enriches question.
- Attachment-only and text-only messages still build expected payload.

## Risks and Mitigation

- Risk: subtle payload drift after extraction.
  - Mitigation: keep key names and merge order identical.
- Risk: reply-context regressions on edge payloads.
  - Mitigation: migrate logic verbatim first, then clean style in follow-up.
- Risk: hidden coupling with external API assumptions.
  - Mitigation: avoid changing endpoint paths, headers, timeout values.

## Enterprise Compatibility Notes

- No direct `enterprise/` Jangkau service counterpart detected.
- Keep public behavior stable to avoid side effects in shared code paths.

## Rollout Strategy

- Merge sequentially per PR step above.
- Validate manually after each PR on:
  - first-message greeting path
  - fallback path
  - WhatsApp reply-context path
  - attachment path

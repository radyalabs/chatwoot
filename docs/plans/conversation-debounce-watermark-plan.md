# Plan: Prevent Reprocessing Old User Messages in Debounce Flow

## Context

Current debounce behavior defines "processed" using `last_ai_reply_at`. This causes reprocessing when:

- Burst A is already invoked to AI,
- AI reply is delayed/asynchronous,
- New message arrives before AI reply is persisted.

Result: old messages from Burst A can be included again in Burst B.

## Target Behavior

When a new debounce invocation is created, only messages that have not already been included in a previous invocation should be included.

Example:

1. `Okaaay...\nEeeh...\nKenalin...` -> processed as Burst A
2. `Kak, bisa ke sana gak yaa?` -> processed alone as Burst B

## Design Decision

Use a conversation-level watermark:

- Key: `last_debounced_processed_message_id`
- Location: `Conversation.additional_attributes`
- Update timing: right after `ProcessDebouncedConversationJob` enqueues `ChatServiceJob`

This makes "already processed by debounce" independent from "AI reply already written".

## Implementation Plan

1. Add boundary helpers in `Captain::Copilot::State::ConversationAiState`
   - Read watermark from `conversation.additional_attributes`.
   - Compute effective processing boundary:
     - prefer watermark when present,
     - fallback to last AI reply boundary for backward compatibility.

2. Update `Captain::Copilot::ProcessDebouncedConversationJob`
   - Build `burst_messages` using boundary by `id` (messages with `id > boundary_id` up to `latest_message.id`).
   - Keep existing superseded and `max_wait` checks.

3. Add conversation-level serialization in `ProcessDebouncedConversationJob`
   - Use PostgreSQL advisory lock keyed by `conversation_id`.
   - Wrap decision + enqueue + watermark update in one critical section.

4. Persist watermark after enqueue
   - Save `last_debounced_processed_message_id = latest_message.id`.
   - Enforce monotonic update (`max(existing, latest_message.id)`) to avoid moving backward.

5. Observability updates
   - Add log fields: `processing_boundary_id`, `watermark_before`, `watermark_after`.
   - Keep invocation metric and noop metric unchanged.

## Spec Plan

Update `spec/jobs/captain/copilot/process_debounced_conversation_job_spec.rb` with:

1. "Does not include already processed messages"
   - Given watermark points to previous latest message,
   - Next invocation includes only newer messages.

2. "Works when AI reply is still absent"
   - No new `AiAgent` message persisted,
   - Watermark still prevents replay of old burst.

3. "Watermark update is monotonic"
   - Existing watermark greater than candidate does not get reduced.

4. "Concurrent jobs remain single effective window"
   - Under lock, overlapping jobs do not enqueue duplicate overlapping windows.

## Rollout Notes

- Keep `CAPTAIN_DEBOUNCE_ENABLED` kill switch behavior unchanged.
- No schema migration required for first version (uses existing jsonb field).
- If query/read complexity grows, follow-up can move watermark to a dedicated column.

## Risks and Mitigations

- Risk: jsonb update races without locking.
  - Mitigation: advisory lock around read/compute/enqueue/write sequence.

- Risk: old conversations without watermark.
  - Mitigation: fallback to current last-AI-reply behavior.

- Risk: stale watermark from manual data edits.
  - Mitigation: monotonic max update and safe fallback behavior.

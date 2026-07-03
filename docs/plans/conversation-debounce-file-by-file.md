# Plan: Conversation Debounce (File-by-File)

**Reference spec:** `docs/specs/conversation-debounce-spec.md`  
**Last updated:** 2026-07-02

This plan turns the v2 spec into a concrete implementation checklist by file, with minimal moving parts (no Redis, no fencing token), and keeps rollout guarded by `CAPTAIN_DEBOUNCE_ENABLED`.

## 1) Core code changes

| Order | File | Change |
|---|---|---|
| 1 | `app/services/captain/copilot/conversation_ai_state.rb` (new) | Add shared conversation-level helper(s) used by both `ChatService` and `BaseJangkauService`: whether conversation already has AI reply, last AI reply timestamp, and first incoming message in current burst window. |
| 2 | `app/services/captain/copilot/chat_service.rb` | Replace duplicated `welcome_message?` logic (`incoming.count == 1`) with the shared helper from step 1. Add support for burst payload input (combined question string + combined attachments) while keeping existing single-message path unchanged. Ensure `attachments:` is forwarded to `AssistantChatService.new(...)`. |
| 3 | `app/services/captain/llm/base_jangkau_service.rb` | Replace duplicated `first_message?` logic with shared helper from step 1 so welcome/completion routing stays consistent with `ChatService`. Keep string-question behavior as-is (accepted WhatsApp reply-context regression for multi-message burst remains intentional per spec §3). |
| 4 | `app/services/captain/copilot/message_debouncer.rb` (new) | Stateless scheduler wrapper. `schedule` enqueues `Captain::Copilot::ProcessDebouncedConversationJob.perform_in(debounce_interval.seconds, conversation_id, message_id)`. No writes/state storage. |
| 5 | `app/jobs/captain/copilot/process_debounced_conversation_job.rb` (new) | Implement trailing-edge decision: latest-message re-check, `max_wait` ceiling check, gather burst messages, build combined question for multi-message burst, aggregate attachments across burst, trigger one downstream AI invocation. Early-return no-op when superseded by newer message. |
| 6 | `app/jobs/captain/copilot/chat_service_job.rb` | Extend job input to support debounced payload (message anchor + optional combined question + optional aggregated attachments metadata) while preserving current `perform(message_id)` behavior for kill-switch off path. |
| 7 | `app/listeners/action_cable_listener.rb` | Replace direct `ChatServiceJob.perform_later(message.id)` with `MessageDebouncer.new(message).schedule` when message is eligible and `CAPTAIN_DEBOUNCE_ENABLED == 'true'`; keep direct legacy call when disabled. |

## 2) Config and env surface

| File | Change |
|---|---|
| `.env.example` | Add `CAPTAIN_DEBOUNCE_ENABLED`, `CAPTAIN_DEBOUNCE_INTERVAL_SECONDS`, `CAPTAIN_DEBOUNCE_MAX_WAIT_SECONDS` with spec defaults (`true`, `10`, `60`). |
| `app.json` | Add the same env vars so deployment templates expose them in managed environments. |

## 3) Observability (required at launch)

| Order | File | Change |
|---|---|---|
| 1 | `app/jobs/captain/copilot/process_debounced_conversation_job.rb` | Emit metrics for: messages-combined-per-invocation, time from first message in burst to invocation, no-op superseded job rate. |
| 2 | `app/jobs/captain/copilot/chat_service_job.rb` (or same debounced job) | Emit post-debounce AI invocation failure metric (separate dimension/tag from current baseline). |

Note: exact metric backend call shape should follow existing project telemetry conventions during implementation.

## 4) Test files to add/update

| File | Change |
|---|---|
| `spec/listeners/action_cable_listener_spec.rb` | Assert debounce-on path schedules debouncer and debounce-off path falls back to direct `ChatServiceJob`. |
| `spec/jobs/captain/copilot/process_debounced_conversation_job_spec.rb` (new) | Cover latest-message no-op, trailing-edge execution, `max_wait` ceiling behavior, combined question ordering, one-invocation guarantee. |
| `spec/jobs/captain/copilot/chat_service_job_spec.rb` (new) | Verify backward compatibility for single `message_id` call and new debounced payload call path. |
| `spec/services/captain/llm/base_jangkau_service_spec.rb` | Update/add examples to validate shared first-message routing still selects welcome endpoint correctly after helper extraction. |

## 5) Rollout gating and open follow-up

- Create follow-up ticket before enabling in production for accepted regression in spec §3 (WhatsApp reply-context loss for multi-message burst). Keep ticket reference in this plan once created.
- Roll out with `CAPTAIN_DEBOUNCE_ENABLED=false` first, then enable gradually.
- Immediate rollback path is env toggle back to `false` (no deploy required).

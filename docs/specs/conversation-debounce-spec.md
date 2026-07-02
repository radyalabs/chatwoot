# Spec: Conversation-Level Trailing-Edge Debounce for AI Agent Invocation

**Status:** Ready for implementation, pending sign-off on §5 reply-context trade-off (v4 — integration point confirmed)
**Owner:** TBD
**Last updated:** 2026-07-02
**Scope:** `Captain::Copilot::ChatService` → `Captain::Llm::AssistantChatService` → `Captain::Llm::BaseJangkauService` (Jangkau branch confirmed; `BaseFlowiseService`/custom-agent branch NOT yet reviewed — see §8)

## 0. Correction From v2

v2 assumed the buffer didn't need to store message content, because `AssistantChatService` receives `@context.conversation` alongside `@message`. **That assumption was wrong.** Confirmed from `base_jangkau_service.rb#extract_message_data`: the "question" sent to the external Jangkau agent API is built from a single `@message.content` — the conversation object is only used for `session_id`/`conversation_id`/`inbox_id` metadata in `override_config`, not for pulling message history. The external agent API is presumably stateful per `session_id`, and Chatwoot sends one incremental question per call — meaning a debounced burst of N messages must be **concatenated into one combined question string** before firing, not resolved by simply pointing at the last message. v1's original approach (buffer content) was correct; v2's simplification is discarded.

## 1. Problem Statement

`ChatService#perform` fires once per inbound message today (call site itself still not located — §9, still blocking). A burst of N rapid customer messages currently produces N separate calls to the external Jangkau/Flowise agent API, each with only that single message's text as context. Goal: batch a burst into exactly one invocation, with one combined question string covering the whole burst.

## 2. Data Model

Per `conversation_id`, in Redis:

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `debounce:{conversation_id}:token` | String (UUID) | `max_wait + grace` | Fencing token for the current pending invocation |
| `debounce:{conversation_id}:first_seen_at` | Integer (epoch ms) | same | Start of burst window, for `max_wait` |
| `debounce:{conversation_id}:message_ids` | List of integers | same | Ordered IDs of buffered incoming messages in this burst |

Message *content* itself does not need duplicating into Redis — only IDs — because at fire time the job re-reads the actual `Message` records from Postgres in order and builds the combined question then. This avoids stale/duplicated content in Redis and keeps the buffer small.

## 3. Flow

1. Inbound message arrives, would previously call `ChatService.new(message).perform` directly.
2. Append `message.id` to `debounce:{id}:message_ids`. If `first_seen_at` unset, set it now.
3. `deadline = min(now + debounce_interval, first_seen_at + max_wait)`.
4. New fencing token generated, stored; delayed job scheduled for `deadline` (same `perform_at` pattern already used by `Conversations::AddIdleConversationJob`).
5. **Job fires:**
   - Token mismatch → stale, exit.
   - Token match → atomically clear `token`, `first_seen_at`, `message_ids`; load the actual `Message` records for those IDs in order; build the combined question (§4); call `ChatService` with the necessary changes below.

## 4. Combined Question Construction

Given the buffered `Message` records in order:

- If the buffer has exactly **one meaningful message** (the common, non-burst case): pass it through to `ChatService`/`AssistantChatService` exactly as today. Zero behavior change for the majority of traffic.
- If the buffer has **more than one meaningful message**: concatenate their `.content` values (e.g. newline-joined, in order) into a single string, and pass that string in place of the `Message` object at the `AssistantChatService`/`BaseJangkauService` boundary. This works cleanly because `extract_message_data` already special-cases a `String` input (`if @message.is_a?(String) then [@message, {}]`) — no change needed there for the question text itself.
- **Trade-off this creates:** passing a `String` instead of a `Message` skips `enrich_question_with_reply_context` (WhatsApp reply-quote enrichment) and the `is_a?(Message)`-gated attachment fallback. Reply-context enrichment being skipped for multi-message bursts is likely acceptable (a reply-quote tied to one specific message in a burst is an edge case), but this is a product call, not an engineering default — flag for sign-off.
- **Required code change, not optional:** `ChatService#send_messages` must start passing `attachments:` through to `AssistantChatService.new(...)`, gathering attachments from **all** buffered messages, not just the last one. Today this kwarg isn't forwarded at all, so even a single-message-with-image case relies on the `last_message_attachments` fallback inside `BaseJangkauService` — that fallback breaks the moment `@message` is a `String` instead of a `Message`, so explicit `attachments:` passing becomes mandatory once bursts are combined into strings.
- **Confirmed low-cost:** attachments are sent as blob references (`key`, `file_type`, `filename`, `url`) that the external agent fetches on its own side — not raw binary through this pipeline. Concatenating attachment arrays across every buffered message in a burst therefore has negligible payload cost; no batching/size concern here. Order attachments to match the chronological order of the buffered messages so the agent can associate each blob with roughly the right point in the combined question, even though there's no strict positional binding once text is flattened into one string.

## 5. The "First Message" Check Exists in Two Places — Both Must Be Fixed Together

Identical logic, duplicated:

```ruby
# chat_service.rb
def welcome_message?
  ...
  @context.conversation.messages.incoming.where(private: false).count == 1
end

# base_jangkau_service.rb
def first_message?(conversation)
  conversation.messages.incoming.where(private: false).count == 1
end
```

Once debounce delays invocation, a first-contact burst of 3 messages makes both of these evaluate `count == 3`, not `1`. Two independent, currently-correct behaviors will silently break at the same time:

1. `ChatService` will not send greeting images on what is, from the customer's perspective, their first contact.
2. `BaseJangkauService` will route to `/v2/chat/completion/` instead of `/v2/chat/welcome/`, meaning the external agent API itself never gets told this is a welcome turn.

**Recommendation:** extract a single shared check — e.g. "no AI Agent reply exists yet for this conversation" (checking `messages.where(sender_type: 'AiAgent').none?` or similar) instead of counting incoming messages — and have both call sites use it. Fixing one without the other will leave a half-working, hard-to-debug inconsistency between the dashboard experience and what the external agent API believes is happening.

## 6. Configuration

Global, via `.env` (per your decision):

| Variable | Suggested default |
|---|---|
| `CAPTAIN_DEBOUNCE_INTERVAL_SECONDS` | 10 |
| `CAPTAIN_DEBOUNCE_MAX_WAIT_SECONDS` | 60 |

[Guessing] Defaults are placeholders pending real usage data.

## 7. Failure Handling — Per Your Decision

No retry, no automatic handover — skip. `ChatService`'s existing internal failure path (`send_reply_failure`, triggered by subscription limits or a failed `AssistantChatService` call) is unaffected by this change and still applies once the debounced job actually calls `ChatService`. The only new failure mode is the delayed job itself never firing (worker crash, queue issue) — recommendation within the "skip" boundary: log it (`Rails.logger.warn`) for visibility, add nothing beyond that.

## 8. `custom_agent` / Flowise Branch — Explicitly Out of Scope

Per product decision: `BaseFlowiseService` is no longer in active use, so this spec does not cover it. Implementation targets the `BaseJangkauService` path only.

**Residual risk to guard against, not to solve now:** `ChatService`/`AssistantChatService` still branch on `@ai_agent.custom_agent?` at the code level — nothing prevents an account from being configured with a custom agent in the future. If that happens, debounce would still fire and hand a combined `String`/attachment array into a code path (`BaseFlowiseService`) that was never verified to handle either correctly. Recommendation: add a log line (e.g. `Rails.logger.warn` if `custom_agent?` is true at debounce-fire time) so this silently-wrong scenario is at least visible in logs rather than failing invisibly. Not a blocker for this build, but cheap insurance.

## 9. Integration Point — Confirmed

Found in `app/listeners/action_cable_listener.rb#message_created`:

```ruby
def message_created(event)
  message, account = extract_message_and_account(event)
  ...
  Captain::Copilot::ChatServiceJob.perform_later(message.id) if message.sender_type == 'Contact'
  broadcast(account, tokens, MESSAGE_CREATED, message.push_event_data)
end
```

This is a single, event-driven call site (Wisper-style dispatch off `Message` creation), already filtered to `sender_type == 'Contact'` — not scattered per-channel as earlier assumed. This is where the debounce wrapper replaces the direct job call:

```ruby
# Before:
Captain::Copilot::ChatServiceJob.perform_later(message.id) if message.sender_type == 'Contact'

# After:
Captain::Copilot::MessageDebouncer.new(message).schedule if message.sender_type == 'Contact'
```

`Captain::Copilot::ChatServiceJob` itself is unchanged — it remains the simple `Message.find(message_id)` → `ChatService.new(message).perform` wrapper, and is exactly what the debounce-fire job (component #3 from the architecture discussion) calls at the end of its run, whether the buffer resolved to a single message or a combined string.

**Minor item to confirm during implementation, not a blocker:** the `sender_type == 'Contact'` filter is assumed sufficient to exclude activity messages and private notes from reaching the debouncer — worth a quick check against the `Message` model rather than taking on faith.

## 11. Architecture — Three Components

1. **Interception point** — `ActionCableListener#message_created`, per §9. Do not put debounce logic inside `ChatService` itself.
2. **`Captain::Copilot::MessageDebouncer`** (new service) — owns Redis buffering: append message ID, compute deadline, generate fencing token, schedule the delayed job. Knows nothing about AI Agents, welcome messages, or attachments.
3. **Delayed job** (new, e.g. `Captain::Copilot::ProcessDebouncedConversationJob`), scheduled via `perform_at` — checks the fencing token, loads buffered `Message` records, builds the combined question per §4, then calls `Captain::Copilot::ChatServiceJob.perform_later(message_id)` (single-message case) or an equivalent path that hands `ChatService` the combined string (burst case).

## 10. Resolved Decisions

1. `max_wait` approved (§3).
2. AI invocation failure: no retry, no handover — skip, log only (§7).
3. Config: global via `.env` (§6).
4. Mid-buffer human handover: out of scope, feature doesn't exist in this fork.
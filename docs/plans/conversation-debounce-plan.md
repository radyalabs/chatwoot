# Planning: Conversation-Level Trailing-Edge Debounce Rollout

**Reference spec:** `conversation-debounce-spec.md` — this document does not repeat technical design, only sequencing, testing, rollout, and tracking.
**Last updated:** 2026-07-02

## 1. Implementation Order

Build in this order — each step is independently testable before moving to the next, per the 3-component architecture in spec §10.

| Step | Component | Depends on | Spec ref |
|---|---|---|---|
| 1 | Fix duplicated "first message" check — extract shared helper, update both call sites | Nothing (standalone fix, ships safely even without debounce) | §4 |
| 2 | Add `attachments:` forwarding in `ChatService#send_messages` → `AssistantChatService` | Nothing (also standalone — fixes an existing gap even for single-message case) | §3 |
| 3 | `Captain::Copilot::MessageDebouncer` (schedules `ProcessDebouncedConversationJob.perform_in`) | Steps 1–2 | §2, §10 |
| 4 | `Captain::Copilot::ProcessDebouncedConversationJob` (latest-message check, `max_wait` check, combined question construction, calls `ChatServiceJob`) | Step 3 | §2, §3, §10 |
| 5 | Wire `ActionCableListener#message_created` to call `MessageDebouncer` instead of `ChatServiceJob` directly, gated by `CAPTAIN_DEBOUNCE_ENABLED` | Step 4 | §5, §8 |
| 6 | Observability: metrics/logging from §7 | Step 5 | §7 |

**Why steps 1 and 2 go first, standalone:** both are real bugs today, independent of debounce. Shipping them separately means they're validated against production traffic before debounce logic adds another variable on top — if something breaks after step 1 or 2 ships, you know immediately it's not the debounce mechanism.

## 2. Testing Checklist

Not exhaustive test-writing — the specific scenarios that must be covered, because they're the ones a generic test suite tends to miss:

- [ ] Single message, no burst — debounce path produces identical `ChatService` behavior to today (regression baseline).
- [ ] Burst of 3+ messages arriving within `debounce_interval` — exactly one AI invocation fires, combined question contains all message contents in order.
- [ ] Burst that exceeds `max_wait` while messages keep arriving under `debounce_interval` apart — invocation fires at the `max_wait` ceiling, not later.
- [ ] Two messages arriving near-simultaneously (race) — only one job proceeds; the other exits as a no-op via the "am I still the latest" check (§2 step 2).
- [ ] First-contact burst (3 messages, no prior AI reply) — greeting images still send correctly, and Jangkau API is called with `/v2/chat/welcome/`, not `/v2/chat/completion/` (validates the §4 fix didn't regress).
- [ ] Attachments split across multiple messages in one burst — all attachments reach the external agent API, not just the last message's.
- [ ] `CAPTAIN_DEBOUNCE_ENABLED=false` — behavior reverts exactly to today's direct `ChatServiceJob.perform_later` call, no debounce delay at all.
- [ ] Subscription/usage limit exceeded mid-burst — `pre_check_failure_reason` still correctly blocks and calls `send_reply_failure` once for the batch, not once per buffered message.

## 3. Rollout

1. Ship steps 1–2 (standalone fixes) to production first, independent of debounce. Confirm no regression via existing monitoring before proceeding.
2. Ship steps 3–6 with `CAPTAIN_DEBOUNCE_ENABLED=false` by default — code is live but inert.
3. Enable in staging / a single low-traffic test account. Watch §7 metrics (messages-combined-per-invocation, time-to-invocation, no-op job rate) for at least a few days of real traffic patterns.
4. Enable for production gradually if the platform supports per-account or per-inbox flag overrides; otherwise, enable globally with the kill-switch as the rollback path (§5) — flipping `CAPTAIN_DEBOUNCE_ENABLED=false` requires no deploy.
5. Confirm §7's no-op job rate and combined-messages distribution look sane (not e.g. every burst hitting `max_wait`, which would suggest `debounce_interval` is set too short for real customer typing cadence).

## 4. Tracking / Follow-ups

- **Follow-up spec — WhatsApp reply-quote enrichment for multi-message bursts** (spec §3): known, accepted regression on ship. **Ticket reference: TBD — create before step 5 (production rollout) begins**, so this isn't only tracked in a markdown file nobody revisits.
- **Communication to product/support:** confirm before rollout that whoever handles WhatsApp customer support is aware reply-quote context will be lost for burst messages until the follow-up ships (per earlier discussion — this is a communication task, not an engineering one, but it blocks a responsible rollout).
- **Confirm queue adapter:** verify `config.active_job.queue_adapter` is Sidekiq (open source `perform_in`/`perform_at` is sufficient — confirmed not an Enterprise feature) before relying on the scheduling approach in spec §2.
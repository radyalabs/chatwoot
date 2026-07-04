# Per AI Agent Debounce Config Plan

## Objective

Add debounce configuration scoped to each `AiAgent` while keeping a global emergency kill-switch.

## Agreed Decisions

1. Scope is per `AiAgent` record (`ai_agents.id`), not per key inside `flow_data.vars`.
2. Config source is `display_flow_data.debounce_config` (not `flow_data`) so it is not sent in Jangkau request body.
3. Global kill-switch remains authoritative:
   - `CAPTAIN_DEBOUNCE_ENABLED=false` => debounce OFF for all agents.
4. When global kill-switch is ON (`CAPTAIN_DEBOUNCE_ENABLED=true`), evaluate per-agent config:
   - `enabled=false` => debounce OFF for that agent.
   - `enabled=true` + valid values => debounce ON using per-agent values.
   - `enabled=true` + invalid values => debounce OFF for that agent (direct `ChatServiceJob`).
   - `debounce_config` absent => debounce OFF for that agent (direct `ChatServiceJob`).

## Config Shape

```json
{
  "debounce_config": {
    "enabled": true,
    "interval_seconds": 10,
    "max_wait_seconds": 60
  }
}
```

## Default Values on AI Agent Creation

When a new `AiAgent` is created, initialize `display_flow_data.debounce_config` with:

- `enabled=false`
- `interval_seconds=15`
- `max_wait_seconds=60`

## Validation Rules

- `interval_seconds` must be an integer `>= 5`.
- `max_wait_seconds` must be an integer `>= 30`.
- `max_wait_seconds >= interval_seconds`.
- Invalid per-agent config with `enabled=true` must disable debounce for that agent.

## Implementation Plan

1. Add `Captain::Copilot::DebounceConfig` resolver service to centralize precedence and validation logic.
2. Integrate resolver in `ActionCableListener#message_created` to choose debounced vs direct path.
3. Integrate resolver in `MessageDebouncer` for per-agent interval scheduling.
4. Integrate resolver in `ProcessDebouncedConversationJob` for per-agent `max_wait_seconds`.
5. Ensure AI agent create paths set default `debounce_config` in `display_flow_data`.
6. Add warning logs when per-agent config is invalid and debounce is forced OFF.

## Files To Change

- `app/services/captain/copilot/config/debounce_config.rb` (new)
- `app/listeners/action_cable_listener.rb`
- `app/services/captain/copilot/message_debouncer.rb`
- `app/jobs/captain/copilot/process_debounced_conversation_job.rb`
- `app/builders/v2/ai_agents/ai_agent_builder.rb`
- `app/builders/v2/ai_agents/ai_agent_custom_builder.rb`

## Test Plan

- Add `spec/services/captain/copilot/debounce_config_spec.rb` for precedence/validation matrix.
- Update `spec/listeners/action_cable_listener_spec.rb`:
  - global kill-switch false always direct path,
  - global true + per-agent false direct path,
  - global true + per-agent true valid debounced path,
  - global true + per-agent true invalid direct path.
- Update `spec/services/captain/copilot/message_debouncer_spec.rb` for per-agent interval behavior.
- Update `spec/jobs/captain/copilot/process_debounced_conversation_job_spec.rb` for per-agent max-wait behavior.

## Notes

- Agents without `debounce_config` are treated as debounce disabled.
- No changes to Jangkau request schema are required for this plan.

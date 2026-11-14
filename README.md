# Stratus

Cloud-agnostic infrastructure agent: chat (and later voice) with AWS, Google Cloud,
Azure and codesphere at once. The agent investigates in the background and builds
UI on the fly (charts, dependency maps, tables, action buttons).

> All cloud data is simulated for the demo. The UI, the block protocol and the
> agent seam are real.

## Run

```bash
flutter create . --platforms web --project-name stratus   # only once, adds web/
flutter pub get
flutter run -d chrome
```

Try: "Why is my checkout slow?" → "Roll back…" → "Run rollback".
Also: "Where can I cut cloud costs?", "What changed in the last 24h?".

## Architecture

```
lib/
  agent/agent_service.dart   AgentService + AgentEvent (the seam)
  agent/mock_agent.dart      scripted agent, emits JSON blocks
  agent/mock_scenarios.dart  demo scenarios
  models/ui_block.dart       generative-UI block types + UiBlock.fromJson
  state/chat_controller.dart applies the event stream to messages
  widgets/blocks/            one widget per block type
  widgets/                   chat surface (sidebar, composer, messages, steps)
```

Agent → UI events: `StepStarted`, `StepCompleted`, `TextChunk`, `BlockEmitted`.

## Block protocol (what the LLM emits via a `render_ui` function call)

| type         | fields |
|--------------|--------|
| `stats`      | `items[{label, value, delta?, good?}]` |
| `line_chart` | `title, subtitle?, source?, unit, labels[], series[{name, values[], color?}], threshold?, threshold_label?, highlight_from?, highlight_label?, highlight_severity?` |
| `bar_chart`  | `title, subtitle?, source?, unit, bars[{label, value, sublabel?, highlight?}]` |
| `topology`   | `title, subtitle?, nodes[{id, label, provider, region, status}], edges[{from, to, label, status}]` |
| `finding`    | `title, body (**bold**, \`code\`), severity, evidence[]?` |
| `table`      | `title, subtitle?, columns[], rows[][], highlight_rows[]?` |
| `actions`    | `title?, actions[{id, label, variant, icon?}]` |

`severity` / `status`: `info | success | warning | critical`.
`variant`: `primary | secondary | outline | ghost | destructive`.
`provider`: `aws | gcp | azure | codesphere`.

## Next: Gemini

Implement `GeminiAgent implements AgentService`:
- tools such as `get_metrics`, `get_traces`, `get_costs`, `get_topology` read the mock data → emit `StepStarted`/`StepCompleted`
- a `render_ui` tool with the schema above → `BlockEmitted(UiBlock.fromJson(args))`
- streamed text → `TextChunk`
- action button clicks come back as `send(label, actionId: id)`

Then swap `MockAgent()` in `main.dart`. The mic button exposes `Composer.onMicToggle` for Gemini Live.

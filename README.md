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

## Generative UI showcase

Open the "Checkout is slow in West Europe" incident, then ask (or click the chips):

| Question | Diagram it creates |
|---|---|
| Which regions are affected? | Heatmap: latency by region × hour (EU red, US East got faster) |
| Show me the trace of a slow checkout | Trace waterfall: 3 sequential cross-Atlantic payment calls |
| How does this affect conversion? | Funnel vs. last week: drop-off at the payment step |
| What happened, step by step? | Incident timeline: deploy → spike → muted alert → root cause |
| How much error budget have we burned? | SLO gauges + burn-down with dashed projection |
| What if we don't fix this before Black Friday? | Revenue projection with/without fix + loss stats |

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
| `brief`      | `title, severity, badge?, items[{label, text}]` |
| `heatmap`    | `title, subtitle?, source?, unit, threshold?, x_labels[], y_labels[], values[][]` |
| `waterfall`  | `title, subtitle?, source?, spans[{name, provider, start, duration, depth, highlight?}]` |
| `funnel`     | `title, subtitle?, source?, value_label, compare_label?, steps[{label, value, compare?}]` |
| `timeline`   | `title, subtitle?, events[{time, title, detail?, provider?, severity}]` |
| `gauges`     | `items[{label, value (0..1), display, caption?, severity}]` |
| `followups`  | `title?, questions[]` |

`line_chart` series also accept `dashed_from` (index) to draw a projection.

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

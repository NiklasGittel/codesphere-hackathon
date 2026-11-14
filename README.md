# Stratus – an AI SRE for every cloud

**Stratus** is an AI agent you can talk to (by chat or voice) about your cloud infrastructure and your business.
Ask *"Why is my checkout slow?"* or *"Where can we cut cloud costs?"* and Stratus investigates across
providers, finds the root cause, explains it with **charts it generates on the fly**, and proposes a fix
that a human approves with one click.

Built in one day at the **{Tech: Europe} Agentic AI Hack** in Karlsruhe, co-hosted by
**Google DeepMind** and **codesphere**.

> All infrastructure data is **simulated** for the demo. The agent, its tool calls, the generated UI and the
> approval flow are real.

---

## The problem

Modern shops run on several clouds at once. When checkout gets slow, the evidence is spread across
CloudWatch, Cloud Trace, Azure Monitor, deploy logs and billing exports. Finding the cause takes hours,
and the people who feel the impact (business, management) can't read any of these dashboards.

## What Stratus does

1. **Overview first.** A start page shows open incidents and savings opportunities across all providers at a glance.
2. **Investigates like an SRE.** The agent plans its investigation and calls tools for metrics, traces, logs,
   deploys, funnel data, SLOs and costs, in parallel when it makes sense. Every tool call is visible as a step.
3. **Answers visually (generative UI).** Instead of walls of text, the agent builds the answer from UI
   components: a concise *What / Impact / Cause / Fix* breakdown, then evidence such as a latency heatmap by
   region, a trace waterfall, a conversion funnel, an incident timeline, SLO gauges or a revenue projection
   up to Black Friday.
4. **Human in the loop.** Fixes (rollback, scaling, rightsizing) are proposed as buttons. Nothing changes until
   a human confirms. The tools themselves are read-only.
5. **Voice.** Tap the mic, ask your question, and Gemini transcribes it.

---

## How we use our technology partners

### Google DeepMind – Gemini

Gemini is the brain of Stratus. We use it in four ways:

| Capability | Where | What it does |
|---|---|---|
| **Function calling (agent loop)** | `lib/agent/gemini/` (Flutter), `backend/agent.py` | Gemini decides which tools to call (metrics, traces, logs, service graph, costs, …), reads the results, reasons about them over several turns and reaches a root cause. |
| **Generative UI via function calls** | `lib/agent/gemini/prompt.dart` | Two UI tools, `show_data(data_id)` and `render_ui(component_json)`, let Gemini decide *which* visualization explains the problem best and compose its own components (briefs, stats, tables, action buttons, follow-up questions). The Flutter client renders them natively. |
| **Audio understanding (voice input)** | `lib/voice/`, `lib/gemini/gemini_client.dart` | The browser records the question as 16 kHz WAV. Gemini transcribes it with a domain-aware prompt (it knows terms like *p95*, *payment-svc*, *error budget*). |
| **Structured output** | `lib/agent/mock_router.dart` | When the offline playbook is active, Gemini classifies free-form questions into scenarios using a JSON response schema. |

Models are configurable: the frontend defaults to `gemini-flash-latest` (`--dart-define=GEMINI_MODEL=…`), and the
backend uses `GEMINI_MODEL` in `backend/.env` (e.g. `gemini-3.7-flash`). The backend uses the official
**Google GenAI SDK** (`google-genai`).

**Built to survive a live demo:** retries with backoff on rate limits and overload, per-call and total timeouts,
and an automatic fallback to a scripted playbook when Gemini is unreachable.

Other Google technology in the stack:
- **Flutter** (web) for the Stratus dashboard and chat UI.
- **Google Cloud Run** as a one-command deploy target for the backend (see `backend/README.md`).

### codesphere

- **Part of the multi-cloud story.** In the simulated estate, codesphere hosts the storefront and runs the
  deploy pipeline next to AWS, Google Cloud and Azure. Stratus treats it as a first-class provider: its deploy
  history is how the agent links incidents to the change that caused them.
- **Sovereign cloud angle.** Stratus is cloud-agnostic by design, so European teams can mix hyperscalers with a
  sovereign European cloud and still have one agent that understands the whole system.

---

## Architecture

```
┌────────────────────────────┐        ┌───────────────────────────────────────┐
│  Stratus UI (Flutter Web)  │        │  Backend (FastAPI, Python)            │
│  • start page, chat, voice │        │  • simulated infra: checkout →        │
│  • generative UI renderer  │        │    redis-cache → postgres-db          │
│  • GeminiAgent ──────────────► Gemini API ◄── Gemini agent (agent.py)      │
│    (tools on a simulated   │        │  • REST + SSE API, approve endpoint   │
│     multi-cloud estate)    │        │                                       │
└────────────────────────────┘        └───────────────▲───────────────────────┘
                                                      │
                                      ┌───────────────┴───────────────┐
                                      │  Demo shop (demo-site/)       │
                                      │  Three.js 3D product stage,   │
                                      │  "Buy now" hits the backend   │
                                      └───────────────────────────────┘
```

| Folder | What it is |
|---|---|
| `lib/`, `test/`, `pubspec.yaml` | Stratus dashboard and chat (Flutter web). Details: [`docs/frontend.md`](docs/frontend.md) |
| `backend/` | FastAPI backend with the simulated infrastructure, the Gemini SRE agent and the approval API. Details: [`backend/README.md`](backend/README.md) |
| `demo-site/` | The merch shop where the incident is felt: on Black Friday "Buy now" times out with a 504 |

### The generative UI protocol

The agent never sends HTML. It sends small JSON components, which the Flutter client renders with its own design
system (shadcn-style). Supported types: `brief`, `stats`, `line_chart`, `bar_chart`, `heatmap`, `waterfall`,
`funnel`, `timeline`, `gauges`, `topology`, `table`, `finding`, `actions`, `followups`.
The full schema is in [`docs/frontend.md`](docs/frontend.md).

---

## Run it

### Backend + shop

```bash
cd backend
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env                                # add GEMINI_API_KEY
uvicorn main:app --reload --port 8080
```

Shop: http://localhost:8080/shop/ · API docs: http://localhost:8080/docs

### Stratus UI

```bash
flutter create . --platforms web --project-name stratus   # once, generates web/
flutter pub get
flutter run -d chrome --dart-define=GEMINI_API_KEY=your-key
```

Without a key, both parts fall back to scripted playbooks, so the demo always works.

---

## Demo script

1. **Start page:** one critical incident ("Checkout is slow in West Europe") and €11.4k/month in savings.
2. **Open the incident:** Stratus investigates (watch the tool steps) and leads with the breakdown.
3. **Dig deeper** with the suggested questions: *Which regions are affected?* (heatmap) ·
   *Show me the trace of a slow checkout* (waterfall) · *How does this affect conversion?* (funnel) ·
   *What happened, step by step?* (timeline) · *How much error budget have we burned?* (gauges) ·
   *What if we don't fix this before Black Friday?* (projection).
4. **Fix it:** click the rollback button, review the plan, confirm. The estate changes, and later answers
   show the recovery.
5. **Shop + backend:** start Black Friday in the shop, watch checkout fail, let the backend agent find the
   Redis bottleneck two layers behind checkout, approve the scaling, and buy the shirt.

---

## Responsible by design

- **Read-only tools.** Agents can only observe; changes go through an explicit human approval.
- **Grounded answers.** The prompt forbids invented numbers: every figure comes from a tool result.
- **No secrets in the repo.** The backend key lives in `backend/.env` (gitignored), and the frontend key is
  passed at build time. Use demo keys only, because a web build exposes its key.

## Team

- **Niklas Gittel:** Stratus UI (Flutter), generative UI, Gemini agent and voice in the frontend
- **Patrick Beyer:** backend, simulated infrastructure, Gemini SRE agent, demo shop

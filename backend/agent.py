"""
agent.py - The Gemini "AI SRE" agent.

What it does
------------
Given a symptom ("checkout is slow"), the agent investigates the simulated
infrastructure step by step with Gemini function calling, using read-only
tools (service graph, metrics, logs, traces, events). When it has found the
root cause it calls `propose_action`, which only PROPOSES a mitigation.
A human must approve it via POST /api/agent/approve (human-in-the-loop).

Streaming
---------
`investigate()` is a generator of event dicts that main.py streams to the
frontend as Server-Sent Events:

    {"type": "start", "mode": "gemini"|"mock", "model": ...}
    {"type": "thought", "text": "..."}                      # agent reasoning text
    {"type": "tool_call", "step": n, "tool": name, "args": {...}}
    {"type": "tool_result", "step": n, "tool": name, "summary": "...", "result": {...}}
    {"type": "root_cause", "summary": ..., "chain": [...], "evidence": [...],
                           "proposed_action": {...}}
    {"type": "error", "message": ...}
    {"type": "done"}

Modes
-----
* gemini: real agent (needs GEMINI_API_KEY)
* mock:   scripted run using the same real tool outputs - no key needed,
          used as demo fallback if Gemini fails (AGENT_FALLBACK_TO_MOCK).
"""

import json
import logging
import time
import uuid

import config
from infra import SERVICES, infra

log = logging.getLogger("agent")

# Last proposed action, waiting for human approval
pending_action: dict | None = None

SYSTEM_PROMPT = """You are "Gemini On-Call", an AI Site Reliability Engineer.
You investigate production incidents of an e-commerce shop (Tech Europe Merch).

Rules:
- You have READ-ONLY tools. You never change infrastructure yourself.
- Work like a senior SRE: start at the symptom, follow the dependency graph,
  form hypotheses, verify them with metrics, logs and traces, and reject
  hypotheses that the data does not support. Do not stop at the first
  service that looks slow - look for the deepest cause.
- Before each tool call, write ONE short sentence (max 20 words) saying what
  you check and why. Be concise.
- Use at most 8 tool calls.
- Finish by calling `propose_action` exactly once with: the root cause chain
  (from root cause to symptom), concrete evidence (numbers), and ONE
  mitigation that a human can approve. Supported mitigations:
    * resource "redis-cache", action "scale_memory", params {"memory_gb": <number>}
    * resource "checkout-service", action "scale_replicas", params {"replicas": <number>}
"""

TOOLS = [
    {"name": "get_service_graph", "description": "Dependency graph of the shop (which service calls which).",
     "parameters": {"type": "object", "properties": {}}},
    {"name": "get_infra_overview", "description": "Current health and key metrics of all resources plus recent infrastructure events (deploys, config changes, traffic campaigns).",
     "parameters": {"type": "object", "properties": {}}},
    {"name": "query_metrics", "description": "Summary (first/min/max/last) of all metrics of one service over the last N minutes.",
     "parameters": {"type": "object", "properties": {
         "service": {"type": "string", "enum": SERVICES},
         "minutes": {"type": "integer", "description": "time window, default 15"}},
         "required": ["service"]}},
    {"name": "query_logs", "description": "Recent log lines of one service.",
     "parameters": {"type": "object", "properties": {
         "service": {"type": "string", "enum": SERVICES},
         "limit": {"type": "integer", "description": "number of lines, default 20"}},
         "required": ["service"]}},
    {"name": "get_traces", "description": "Recent distributed traces of POST /checkout with per-span durations.",
     "parameters": {"type": "object", "properties": {"limit": {"type": "integer"}}}},
    {"name": "propose_action", "description": "Final step: report the root cause and propose ONE mitigation for human approval.",
     "parameters": {"type": "object", "properties": {
         "summary": {"type": "string", "description": "one-sentence root cause"},
         "chain": {"type": "array", "items": {"type": "string"},
                   "description": "causal chain from root cause to symptom, e.g. ['Traffic x10', 'Redis full', ...]"},
         "evidence": {"type": "array", "items": {"type": "string"}, "description": "key facts with numbers"},
         "resource": {"type": "string"},
         "action": {"type": "string", "enum": ["scale_memory", "scale_replicas"]},
         "params": {"type": "object", "properties": {
             "memory_gb": {"type": "number"}, "replicas": {"type": "integer"}}},
         "expected_effect": {"type": "string"}},
         "required": ["summary", "chain", "evidence", "resource", "action", "params"]}},
]


def run_tool(name: str, args: dict) -> dict:
    """Execute one read-only tool against the simulated infrastructure."""
    log.info("tool %s args=%s", name, args)
    if name == "get_service_graph":
        return infra.service_graph()
    if name == "get_infra_overview":
        return infra.state()
    if name == "query_metrics":
        return infra.metrics_summary(args.get("service", "checkout-service"), int(args.get("minutes", 15)))
    if name == "query_logs":
        return {"service": args.get("service"), "lines": infra.logs(args.get("service", "checkout-service"), int(args.get("limit", 20)))}
    if name == "get_traces":
        return {"traces": infra.traces(int(args.get("limit", 5)))}
    return {"error": f"unknown tool {name}"}


def summarize_result(name: str, result: dict) -> str:
    """Short human-readable one-liner of a tool result for the UI timeline."""
    try:
        if name == "get_service_graph":
            return " -> ".join(e["from"] + "→" + e["to"] for e in result["edges"])
        if name == "get_infra_overview":
            return ", ".join(f"{r['name']}: {r['health']}" for r in result["resources"])
        if name == "query_metrics":
            m = result["metrics"]
            keys = [k for k in ("p95_latency_ms", "hit_rate_percent", "memory_percent", "evictions_per_s",
                                "active_connections", "cpu_percent", "error_rate_percent") if k in m]
            return ", ".join(f"{k}: {m[k]['first']} → {m[k]['last']}" for k in keys[:4])
        if name == "query_logs":
            warn = [line for line in result["lines"] if " WARN " in line or " FATAL " in line]
            return (warn[0].split(" ", 1)[1] if warn else result["lines"][-1].split(" ", 1)[1])[:160]
        if name == "get_traces":
            t = max(result["traces"], key=lambda x: x["duration_ms"])
            slow = max(t["spans"][1:], key=lambda s: s["duration_ms"])
            return f"slowest trace {t['duration_ms']}ms, longest span: {slow['service']} {slow['operation']} {slow['duration_ms']}ms"
    except Exception:  # noqa: BLE001
        pass
    return json.dumps(result)[:160]


def _set_pending(args: dict) -> dict:
    """Store the proposed action for approval and return the root_cause event."""
    global pending_action
    pending_action = {
        "id": uuid.uuid4().hex[:8],
        "resource": args.get("resource"),
        "action": args.get("action"),
        "params": args.get("params") or {},
        "expected_effect": args.get("expected_effect", ""),
    }
    return {"type": "root_cause", "summary": args.get("summary", ""), "chain": args.get("chain", []),
            "evidence": args.get("evidence", []), "proposed_action": pending_action}


def approve(action_id: str | None = None) -> dict:
    """Execute the pending action (human approved). Returns the infra result."""
    global pending_action
    if not pending_action:
        return {"status": "rejected", "reason": "no pending action"}
    if action_id and action_id != pending_action["id"]:
        return {"status": "rejected", "reason": "action id mismatch"}
    a = pending_action
    pending_action = None
    p = a["params"]
    log.info("approved action %s", a)
    result = infra.scale(a["resource"], memory_gb=p.get("memory_gb"), replicas=p.get("replicas"))
    return {"approved_action": a, **result}


# ------------------------------------------------------------------ gemini
def _investigate_gemini(symptom: str):
    """Real agent loop with Gemini function calling."""
    from google import genai
    from google.genai import types

    client = genai.Client(api_key=config.GEMINI_API_KEY)
    tool = types.Tool(function_declarations=[types.FunctionDeclaration(**t) for t in TOOLS])
    cfg = types.GenerateContentConfig(system_instruction=SYSTEM_PROMPT, tools=[tool], temperature=0.2)
    contents = [types.Content(role="user", parts=[types.Part(text=f"Incident: {symptom}. Find the root cause.")])]

    for step in range(1, config.AGENT_MAX_STEPS + 1):
        log.info("gemini call step=%s model=%s", step, config.GEMINI_MODEL)
        resp = client.models.generate_content(model=config.GEMINI_MODEL, contents=contents, config=cfg)
        content = resp.candidates[0].content
        contents.append(content)  # keep full content (incl. thought signatures)
        calls = []
        for part in content.parts or []:
            if part.text and not getattr(part, "thought", False):
                yield {"type": "thought", "text": part.text.strip()}
            if part.function_call:
                calls.append(part.function_call)
        if not calls:
            yield {"type": "error", "message": "Agent stopped without proposing an action."}
            return
        responses = []
        for fc in calls:
            args = dict(fc.args or {})
            yield {"type": "tool_call", "step": step, "tool": fc.name, "args": args}
            if fc.name == "propose_action":
                yield _set_pending(args)
                return
            result = run_tool(fc.name, args)
            yield {"type": "tool_result", "step": step, "tool": fc.name,
                   "summary": summarize_result(fc.name, result), "result": result}
            responses.append(types.Part.from_function_response(name=fc.name, response={"result": result}))
        contents.append(types.Content(role="user", parts=responses))
    yield {"type": "error", "message": "Max steps reached."}


# -------------------------------------------------------------------- mock
MOCK_SCRIPT = [
    ("Checkout is slow - first I check overall health and recent events.", "get_infra_overview", {}),
    ("Let me see how checkout depends on other services.", "get_service_graph", {}),
    ("Is checkout-service itself overloaded? Checking its metrics.", "query_metrics", {"service": "checkout-service"}),
    ("CPU and errors look normal - hypothesis 'checkout overloaded' rejected. Checking traces.", "get_traces", {}),
    ("Time is spent waiting for DB connections. Checking postgres.", "query_metrics", {"service": "postgres-db"}),
    ("Pool exhausted. Why so many queries? Checking the cache in front of the DB.", "query_metrics", {"service": "redis-cache"}),
    ("Hit rate collapsed. Confirming with Redis logs.", "query_logs", {"service": "redis-cache"}),
]


def _investigate_mock(symptom: str):
    """Scripted, demo-safe investigation that uses real tool outputs."""
    for i, (thought, tool, args) in enumerate(MOCK_SCRIPT, start=1):
        yield {"type": "thought", "text": thought}
        time.sleep(config.MOCK_STEP_DELAY_S * 0.4)
        yield {"type": "tool_call", "step": i, "tool": tool, "args": args}
        time.sleep(config.MOCK_STEP_DELAY_S * 0.6)
        result = run_tool(tool, args)
        yield {"type": "tool_result", "step": i, "tool": tool, "summary": summarize_result(tool, result), "result": result}
    s = infra.compute()
    r, d, c = s["redis-cache"], s["postgres-db"], s["checkout-service"]
    target = max(8, int(r["memory_gb"] * 2))
    yield _set_pending({
        "summary": f"Redis cache ({r['memory_gb']:g} GB) is too small for Black Friday traffic: evictions crash the hit rate and overload Postgres.",
        "chain": [f"Traffic x{s['traffic_multiplier']:g} (Black Friday)",
                  f"Redis memory {r['memory_percent']:.0f}% → evictions {r['evictions_per_s']:.0f}/s",
                  f"Cache hit rate 95% → {r['hit_rate_percent']:.0f}%",
                  f"Postgres connections {d['active_connections']:.0f}/{d['max_connections']} (pool exhausted)",
                  f"Checkout p95 {c['p95_latency_ms'] / 1000:.1f}s"],
        "evidence": [f"checkout CPU only {c['cpu_percent']:.0f}% - service itself healthy",
                     f"traces: most time in postgres pool.acquire (~{c['db_wait_ms'] / 1000:.1f}s)",
                     f"redis used {r['used_memory_gb']:.1f}/{r['memory_gb']:g} GB, policy allkeys-lru"],
        "resource": "redis-cache", "action": "scale_memory", "params": {"memory_gb": target},
        "expected_effect": "Hit rate back to ~95%, DB connections drop, checkout ~0.3s",
    })


# ------------------------------------------------------------------ public
def investigate(symptom: str = "Checkout is very slow (p95 > 5s) since a few minutes"):
    """Run the agent and yield UI events (see module docstring)."""
    mode = config.AGENT_MODE
    yield {"type": "start", "mode": mode, "model": config.GEMINI_MODEL if mode == "gemini" else "scripted", "symptom": symptom}
    if mode == "gemini":
        try:
            produced_root_cause = False
            for ev in _investigate_gemini(symptom):
                produced_root_cause |= ev["type"] == "root_cause"
                yield ev
            if produced_root_cause:
                yield {"type": "done"}
                return
        except Exception as e:  # noqa: BLE001
            log.exception("gemini agent failed")
            yield {"type": "error", "message": f"Gemini error: {e}"}
        if not config.AGENT_FALLBACK_TO_MOCK:
            yield {"type": "done"}
            return
        yield {"type": "thought", "text": "(Switching to fallback investigation)"}
    yield from _investigate_mock(symptom)
    yield {"type": "done"}

"""
main.py - FastAPI app: HTTP API of the simulated infrastructure + AI SRE agent.

Endpoints (all JSON, CORS open for the frontend):

  GET  /api/health                      liveness
  GET  /api/infra/state                 all resources with health + metrics + events
  GET  /api/metrics?service=X&minutes=15  time series for charts
  GET  /api/logs?service=X&limit=30     log lines
  GET  /api/traces/checkout?limit=5     distributed traces
  GET  /api/service-graph               dependency graph
  POST /api/checkout                    buy something; waits as long as the infra is slow
  POST /api/incident/start              start "Black Friday"
  POST /api/actions/scale               {"resource":"redis-cache","memory_gb":8}  (manual)
  POST /api/reset                       back to a normal day
  GET|POST /api/agent/investigate       Server-Sent Events stream of agent steps
  POST /api/agent/approve               {"action_id": "..."} execute proposed action

Run:  uvicorn main:app --reload --port 8080
"""

import asyncio
import json
import logging
import os
import threading
import time
import uuid

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

import agent
import config
from infra import SERVICES, infra

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("api")

app = FastAPI(title="AI SRE Demo Backend", version="1.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])


@app.on_event("startup")
def _start_sampler():
    """Start the background thread that records metric history."""
    threading.Thread(target=infra.sample_loop, daemon=True).start()
    log.info("started; agent mode=%s model=%s", config.AGENT_MODE, config.GEMINI_MODEL)


def _check_service(service: str):
    """Raise 404 for unknown service names."""
    if service not in SERVICES:
        raise HTTPException(404, f"unknown service '{service}', use one of {SERVICES}")


# ------------------------------------------------------------------ infra
@app.get("/api/health")
def health():
    """Liveness probe."""
    return {"ok": True, "agent_mode": config.AGENT_MODE}


@app.get("/api/infra/state")
def infra_state():
    """Current health + metrics of all resources and recent events."""
    return infra.state()


@app.get("/api/metrics")
def metrics(service: str = Query(...), minutes: int = 15):
    """Time series of one service (for charts)."""
    _check_service(service)
    return {"service": service, "series": infra.metrics(service, minutes)}


@app.get("/api/logs")
def logs(service: str = Query(...), limit: int = 30):
    """Recent log lines of one service."""
    _check_service(service)
    return {"service": service, "lines": infra.logs(service, limit)}


@app.get("/api/traces/checkout")
def traces(limit: int = 5):
    """Recent traces of POST /checkout."""
    return {"traces": infra.traces(limit)}


@app.get("/api/service-graph")
def service_graph():
    """Dependency graph."""
    return infra.service_graph()


class CheckoutRequest(BaseModel):
    """Optional cart payload - not validated, just echoed."""
    items: list[dict] = []


@app.post("/api/checkout")
async def checkout(req: CheckoutRequest | None = None):
    """Simulate a checkout: really waits as long as the current infra latency (capped)."""
    latency_ms = infra.checkout_latency_ms()
    start = time.time()
    await asyncio.sleep(min(latency_ms / 1000, config.CHECKOUT_MAX_REAL_SLEEP_S))
    took = round((time.time() - start) * 1000)
    log.info("checkout took %sms", took)
    return {"order_id": "TE-" + uuid.uuid4().hex[:6].upper(), "status": "confirmed",
            "duration_ms": took, "items": (req.items if req else [])}


@app.post("/api/incident/start")
def incident_start():
    """Start Black Friday."""
    infra.start_incident()
    return {"status": "incident_started"}


class ScaleRequest(BaseModel):
    """Manual scaling request."""
    resource: str
    memory_gb: float | None = None
    replicas: int | None = None


@app.post("/api/actions/scale")
def scale(req: ScaleRequest):
    """Manually scale a resource (the agent path is /api/agent/approve)."""
    return infra.scale(req.resource, memory_gb=req.memory_gb, replicas=req.replicas)


@app.post("/api/reset")
def reset():
    """Back to a normal day."""
    infra.reset()
    agent.pending_action = None
    return {"status": "reset"}


# ------------------------------------------------------------------ agent
class InvestigateRequest(BaseModel):
    """Symptom description for the agent."""
    symptom: str = "Checkout is very slow (p95 > 5s) since a few minutes"


def _sse(symptom: str):
    """Wrap agent events as Server-Sent Events."""
    for ev in agent.investigate(symptom):
        yield f"data: {json.dumps(ev, default=str)}\n\n"


@app.get("/api/agent/investigate")
def investigate_get(symptom: str = InvestigateRequest().symptom):
    """SSE stream (GET, usable with EventSource)."""
    return StreamingResponse(_sse(symptom), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


@app.post("/api/agent/investigate")
def investigate_post(req: InvestigateRequest | None = None):
    """SSE stream (POST, read with fetch + ReadableStream)."""
    symptom = req.symptom if req else InvestigateRequest().symptom
    return StreamingResponse(_sse(symptom), media_type="text/event-stream",
                             headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})


class ApproveRequest(BaseModel):
    """Approval of a proposed action."""
    action_id: str | None = None


@app.post("/api/agent/approve")
def approve(req: ApproveRequest | None = None):
    """Human approves the agent's proposed action -> it is executed."""
    return agent.approve(req.action_id if req else None)


@app.get("/api/agent/pending")
def pending():
    """Currently proposed action waiting for approval (or null)."""
    return {"pending_action": agent.pending_action}


# Serve the demo shop at http://localhost:8080/shop/ (if the folder exists)
_SHOP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shop")
if os.path.isdir(_SHOP_DIR):
    app.mount("/shop", StaticFiles(directory=_SHOP_DIR, html=True), name="shop")

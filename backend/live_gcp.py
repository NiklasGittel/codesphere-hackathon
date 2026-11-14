"""
live_gcp.py - one REAL resource for the demo: payment-svc on Google Cloud Run.

Read-only by default. The only write is a traffic rollback, and only with
`approved: true` (the UI sends that after the human clicked Confirm and the
Gemini Decisions policy check passed).

Auth: Application Default Credentials. On a laptop run once:
    gcloud auth application-default login
Config (backend/.env):
    LIVE_GCP_PROJECT=<project id>     # empty = live mode off
    LIVE_GCP_REGION=europe-west3
    LIVE_RUN_SERVICE=payment-svc

Endpoints:
    GET  /api/live/status
    GET  /api/live/payment-svc            service, traffic, revisions (+env diff), live latency
    POST /api/live/payment-svc/rollback   {"revision": "payment-svc-v481", "approved": true}
    POST /api/live/payment-svc/reset      rehearsal: all traffic back to the bad revision
"""

import collections
import concurrent.futures
import logging
import os
import threading
import time

import requests
from dotenv import load_dotenv
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

load_dotenv()
log = logging.getLogger("live_gcp")

PROJECT = os.getenv("LIVE_GCP_PROJECT", "")
REGION = os.getenv("LIVE_GCP_REGION", "europe-west3")
SERVICE = os.getenv("LIVE_RUN_SERVICE", "payment-svc")
BAD_REVISION = os.getenv("LIVE_BAD_REVISION", f"{SERVICE}-v482")
# Synthetic traffic: PARALLEL requests every INTERVAL seconds (6 / 2 s = ~3 req/s).
PROBE_PARALLEL = int(os.getenv("LIVE_PROBE_PARALLEL", "6"))
PROBE_INTERVAL_S = float(os.getenv("LIVE_PROBE_INTERVAL_S", "2"))
# Probe waits long enough to measure even a very slow revision.
PROBE_TIMEOUT_S = float(os.getenv("LIVE_PROBE_TIMEOUT_S", "15"))
# The shop checkout gives up on payment-svc after this (shop itself aborts at 8 s).
PAYMENT_TIMEOUT_S = float(os.getenv("LIVE_PAYMENT_TIMEOUT_S", "7.5"))
# Shop checkout calls the real payment-svc (only when live mode is on).
ENABLED = bool(PROJECT)
CHECKOUT_USES_PAYMENT_SVC = ENABLED and os.getenv("LIVE_CHECKOUT_USES_PAYMENT_SVC", "true").lower() == "true"

_API = "https://run.googleapis.com/v2"
router = APIRouter(prefix="/api/live")

# ------------------------------------------------------------------ auth
_creds = None
_creds_lock = threading.Lock()


def _headers() -> dict:
    global _creds
    import google.auth
    from google.auth.transport.requests import Request

    with _creds_lock:
        if _creds is None:
            _creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        if not _creds.valid:
            _creds.refresh(Request())
        return {"Authorization": f"Bearer {_creds.token}", "Content-Type": "application/json"}


def _svc_url() -> str:
    return f"{_API}/projects/{PROJECT}/locations/{REGION}/services/{SERVICE}"


def _short(name: str) -> str:
    return (name or "").split("/")[-1]


# ------------------------------------------------------- Cloud Run reads
_cache: dict = {}
_CACHE_TTL_S = 4.0  # the UI refreshes live charts every 3 s


def _cached(key: str, fetch):
    hit = _cache.get(key)
    if hit and time.time() - hit[0] < _CACHE_TTL_S:
        return hit[1]
    value = fetch()
    _cache[key] = (time.time(), value)
    return value


def get_service() -> dict:
    def fetch():
        r = requests.get(_svc_url(), headers=_headers(), timeout=15)
        r.raise_for_status()
        return r.json()
    return _cached("service", fetch)


def list_revisions() -> list:
    def fetch():
        r = requests.get(f"{_svc_url()}/revisions", headers=_headers(), timeout=15)
        r.raise_for_status()
        return r.json().get("revisions", [])
    return _cached("revisions", fetch)


_HIDDEN_ENV = {"APP_B64"}  # code payload of the no-build deploy, not config


def _env(rev: dict) -> dict:
    containers = rev.get("containers") or [{}]
    return {
        e.get("name"): e.get("value")
        for e in containers[0].get("env", [])
        if e.get("name") and e.get("name") not in _HIDDEN_ENV and len(e.get("value") or "") < 200
    }


def _traffic(svc: dict) -> list:
    latest = _short(svc.get("latestReadyRevision", ""))
    out = []
    for t in svc.get("trafficStatuses") or svc.get("traffic") or []:
        rev = _short(t.get("revision", "")) or latest
        out.append({"revision": rev, "percent": t.get("percent", 0)})
    return out


# ----------------------------------------------------------- live probe
_samples: collections.deque = collections.deque(maxlen=5000)  # (ts, ms, ok, revision)
_uri = ""


def _call(url: str, timeout: float) -> dict:
    t0 = time.perf_counter()
    try:
        r = requests.get(url, timeout=timeout)
        rev = ""
        try:
            rev = r.json().get("revision", "")
        except ValueError:
            pass
        return {"ms": (time.perf_counter() - t0) * 1000, "ok": r.status_code < 500, "revision": rev, "timeout": False}
    except requests.Timeout:
        return {"ms": (time.perf_counter() - t0) * 1000, "ok": False, "revision": "", "timeout": True}
    except requests.RequestException:
        return {"ms": (time.perf_counter() - t0) * 1000, "ok": False, "revision": "", "timeout": False}


def _probe_once(url: str):
    c = _call(url, PROBE_TIMEOUT_S)
    return (time.time(), c["ms"], c["ok"], c["revision"])


_probe_thread: threading.Thread | None = None
_last_round = 0.0


def ensure_probe() -> bool:
    """Start the probe thread if it is not running (self-healing). Returns True if (re)started."""
    global _probe_thread
    if not ENABLED:
        return False
    stalled = _last_round and time.time() - _last_round > max(60, PROBE_TIMEOUT_S * 3)
    if _probe_thread is not None and _probe_thread.is_alive() and not stalled:
        return False
    _probe_thread = threading.Thread(target=probe_loop, daemon=True, name="live-probe")
    _probe_thread.start()
    log.info("live probe (re)started")
    return True


def probe_loop():
    """Background thread: synthetic traffic to /authorize (also feeds the live charts)."""
    global _uri, _last_round
    if not ENABLED:
        return
    me = threading.current_thread()
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=max(1, PROBE_PARALLEL))
    while _probe_thread is None or _probe_thread is me:
        _last_round = time.time()
        try:
            if not _uri:
                _uri = get_service().get("uri", "")
            if _uri:
                for s in pool.map(_probe_once, [f"{_uri}/authorize"] * PROBE_PARALLEL):
                    _samples.append(s)
        except BaseException as e:  # keep probing even if one round fails
            log.warning("probe failed: %s", e)
        time.sleep(PROBE_INTERVAL_S)


def authorize() -> dict:
    """One real call to payment-svc /authorize (used by the shop checkout).
    Gives up after PAYMENT_TIMEOUT_S, like a real client with a deadline."""
    global _uri
    if not _uri:
        _uri = get_service().get("uri", "")
    c = _call(f"{_uri}/authorize", PAYMENT_TIMEOUT_S)
    _samples.append((time.time(), c["ms"], c["ok"], c["revision"]))  # real traffic feeds the live charts
    return {**c, "ms": round(c["ms"])}


def _pct(values, p):
    if not values:
        return None
    v = sorted(values)
    return v[min(len(v) - 1, int(round(p / 100 * (len(v) - 1))))]


def probe_stats(window_s: int = 30, minutes: int = 5, bucket_s: int = 10) -> dict:
    now = time.time()
    recent = [s for s in _samples if s[0] >= now - window_s]
    by_rev = collections.Counter(s[3] for s in recent if s[3])
    buckets = []
    for start in range(int(now - minutes * 60), int(now), bucket_s):
        b = [s for s in _samples if start <= s[0] < start + bucket_s]
        buckets.append({
            "t": time.strftime("%H:%M:%S", time.localtime(start + bucket_s)),
            "p95_ms": round(_pct([s[1] for s in b], 95)) if b else None,
            "error_rate_pct": round(100 * sum(not s[2] for s in b) / len(b), 1) if b else None,
        })
    buckets = [b for b in buckets if b["p95_ms"] is not None]
    return {
        "window_s": window_s,
        "requests": len(recent),
        "p50_ms": round(_pct([s[1] for s in recent], 50) or 0),
        "p95_ms": round(_pct([s[1] for s in recent], 95) or 0),
        "error_rate_pct": round(100 * sum(not s[2] for s in recent) / len(recent), 1) if recent else None,
        "served_by_revision": dict(by_rev),
        "series": buckets,
    }


# ------------------------------------------------------------- endpoints
def _require_enabled():
    if not ENABLED:
        raise HTTPException(503, "live mode off: set LIVE_GCP_PROJECT in backend/.env")


@router.get("/status")
def status():
    ensure_probe()
    return {"enabled": ENABLED, "project": PROJECT or None, "region": REGION, "service": SERVICE,
            "probe_running": bool(_probe_thread and _probe_thread.is_alive()),
            "last_probe_round_s_ago": round(time.time() - _last_round, 1) if _last_round else None}


@router.post("/probe/restart")
def probe_restart():
    """Manually restart the background traffic/probe."""
    _require_enabled()
    global _probe_thread
    _probe_thread = None  # old loop exits after its current round
    ensure_probe()
    return {"probe": "restarted"}


@router.get("/payment-svc")
def payment_svc(fresh: bool = False):
    _require_enabled()
    ensure_probe()
    if fresh:
        _cache.clear()
    try:
        svc, revs = get_service(), list_revisions()
    except requests.HTTPError as e:
        raise HTTPException(502, f"Cloud Run API: {e.response.status_code} {e.response.text[:300]}")
    revisions = sorted(
        ({"revision": _short(r.get("name")), "created": r.get("createTime"), "env": _env(r)} for r in revs),
        key=lambda r: r["created"] or "", reverse=True,
    )
    return {
        "source": "live · Google Cloud Run",
        "service": SERVICE,
        "region": REGION,
        "uri": svc.get("uri"),
        "traffic": _traffic(svc),
        "revisions": revisions,
        "probe": probe_stats(),
    }


class RollbackRequest(BaseModel):
    revision: str
    approved: bool = False


def _set_traffic(revision: str) -> dict:
    _cache.clear()
    target = [{"type": "TRAFFIC_TARGET_ALLOCATION_TYPE_REVISION", "revision": revision, "percent": 100}]
    r = requests.patch(f"{_svc_url()}?updateMask=traffic", headers=_headers(), json={"traffic": target}, timeout=30)
    if r.status_code == 400:  # fall back to a full-object update
        _cache.clear()
        body = get_service()
        body["traffic"] = target
        r = requests.patch(_svc_url(), headers=_headers(), json=body, timeout=30)
    if not r.ok:
        raise HTTPException(502, f"Cloud Run API: {r.status_code} {r.text[:300]}")
    op = r.json()
    _cache.clear()
    log.info("traffic -> %s (operation %s)", revision, op.get("name"))
    return {"status": "rolling out", "revision": revision, "operation": op.get("name")}


@router.post("/payment-svc/rollback")
def rollback(req: RollbackRequest):
    _require_enabled()
    if not req.approved:
        raise HTTPException(403, "rollback needs explicit human approval")
    return _set_traffic(req.revision)


@router.post("/payment-svc/reset")
def reset():
    """Rehearsal reset: traffic back to the bad revision and a clean latency history."""
    _require_enabled()
    result = _set_traffic(BAD_REVISION)
    _samples.clear()
    return {**result, "probe_history": "cleared"}

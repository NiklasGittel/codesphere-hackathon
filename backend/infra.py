"""
infra.py - Simulated cloud infrastructure for the "Tech Europe Merch" shop.

Use case
--------
The demo shows an AI SRE agent finding a root cause that is NOT where the
symptom appears:

    shop -> checkout-service -> redis-cache (4 GB)
                             -> postgres-db (100 connections)

* Normal day: cache hit rate ~95 %, few DB connections, checkout ~300 ms.
* "Black Friday" (incident): traffic x10, the cache working set no longer fits
  into 4 GB -> Redis evicts keys -> hit rate collapses -> every request hits
  Postgres -> connection pool exhausted -> checkout takes ~10 s.
* Trap: checkout-service CPU and error rate stay almost normal, so a human
  looking only at the checkout service sees nothing obvious.
* Fix: scale redis-cache to 8 GB (takes REDIS_SCALE_DURATION_S seconds),
  hit rate recovers, checkout back to ~300 ms.

Everything is computed from a small in-memory state, so the demo is fully
deterministic (plus a bit of noise so charts look real). No real cloud
resources are needed.
"""

import logging
import random
import threading
import time
import uuid
from collections import deque
from datetime import datetime, timezone

import config

log = logging.getLogger("infra")

SERVICES = ["checkout-service", "redis-cache", "postgres-db"]


def _noise(value: float) -> float:
    """Add +-config.NOISE relative random noise to a metric value."""
    return value * (1 + random.uniform(-config.NOISE, config.NOISE))


def _iso(ts: float) -> str:
    """Format a unix timestamp as ISO-8601 UTC string."""
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(timespec="seconds")


class Infrastructure:
    """Holds the simulated state and derives all metrics, logs and traces from it."""

    def __init__(self):
        """Create the infrastructure in its healthy default state."""
        self.lock = threading.RLock()
        self.history = {s: deque() for s in SERVICES}
        self.events = deque(maxlen=50)  # deploys, config changes, scaling ...
        self.reset()

    # ------------------------------------------------------------------ state
    def reset(self):
        """Reset everything to a normal day and pre-fill metric history."""
        with self.lock:
            self.incident_started_at = None
            self.redis_memory_gb = config.REDIS_DEFAULT_MEMORY_GB
            self.scaling_until = None
            self.scaling_target_gb = None
            self.events.clear()
            for s in SERVICES:
                self.history[s].clear()
            now = time.time()
            if config.START_IN_INCIDENT:
                # Black Friday started a few minutes ago -> history shows normal, then the drop
                self.incident_started_at = now - config.INCIDENT_STARTED_MINUTES_AGO * 60
            self._event(now - 3600 * 5, "deploy", "checkout-service", "Deployed checkout-service v2.14.0")
            self._event(now - 3600 * 26, "config", "redis-cache", "maxmemory set to 4gb, policy allkeys-lru")
            # pre-fill history so charts are not empty
            steps = int(config.METRIC_HISTORY_MINUTES * 60 / config.METRIC_SAMPLE_INTERVAL_S)
            for i in range(steps, 0, -1):
                self._record(now - i * config.METRIC_SAMPLE_INTERVAL_S)
            if self.incident_started_at:
                self._event(self.incident_started_at, "traffic", "shop", "Black Friday campaign started (-50% on all merch)")
            log.info("infra reset")

    def start_incident(self):
        """Start the Black Friday traffic spike."""
        with self.lock:
            if self.incident_started_at is None:
                self.incident_started_at = time.time()
                self._event(self.incident_started_at, "traffic", "shop", "Black Friday campaign started (-50% on all merch)")
                log.info("incident started")

    def scale(self, resource: str, memory_gb: float | None = None, replicas: int | None = None) -> dict:
        """
        Apply a mitigation action.

        Only scaling redis-cache memory actually fixes the incident; scaling
        checkout-service replicas is accepted but does not help (realistic
        red herring).
        """
        with self.lock:
            now = time.time()
            if resource == "redis-cache" and memory_gb:
                self.scaling_until = now + config.REDIS_SCALE_DURATION_S
                self.scaling_target_gb = float(memory_gb)
                self._event(now, "scaling", resource, f"Scaling redis-cache {self.redis_memory_gb:g}GB -> {memory_gb:g}GB")
                log.info("scale redis to %s GB", memory_gb)
                return {"status": "scaling", "resource": resource, "target_memory_gb": memory_gb,
                        "eta_seconds": config.REDIS_SCALE_DURATION_S}
            if resource == "checkout-service" and replicas:
                self._event(now, "scaling", resource, f"Scaled checkout-service to {replicas} replicas")
                log.info("scale checkout replicas to %s (no effect)", replicas)
                return {"status": "applied", "resource": resource, "replicas": replicas}
            return {"status": "rejected", "reason": f"unsupported action for {resource}"}

    def _apply_scaling_progress(self, now: float):
        """Finish a running scaling operation once its duration has passed."""
        if self.scaling_until and now >= self.scaling_until:
            self.redis_memory_gb = self.scaling_target_gb
            self._event(now, "scaling", "redis-cache", f"Scaling finished: redis-cache now {self.redis_memory_gb:g}GB")
            self.scaling_until = None
            self.scaling_target_gb = None

    def _event(self, ts: float, kind: str, resource: str, message: str):
        """Store an infrastructure event (deploy, config change, scaling...)."""
        self.events.append({"time": _iso(ts), "ts": ts, "kind": kind, "resource": resource, "message": message})

    # ---------------------------------------------------------------- physics
    def _traffic_multiplier(self, now: float) -> float:
        """Traffic factor: 1 on a normal day, ramps up to x10 on Black Friday."""
        if self.incident_started_at is None or now < self.incident_started_at:
            return 1.0
        progress = min(1.0, (now - self.incident_started_at) / config.INCIDENT_RAMP_S)
        return 1 + (config.INCIDENT_TRAFFIC_MULTIPLIER - 1) * progress

    def compute(self, now: float | None = None) -> dict:
        """Derive all current metrics (without noise) from the state."""
        now = now or time.time()
        with self.lock:
            self._apply_scaling_progress(now)
            traffic = self._traffic_multiplier(now)
            ramp = (traffic - 1) / (config.INCIDENT_TRAFFIC_MULTIPLIER - 1)
            working_set = config.REDIS_WORKING_SET_NORMAL_GB + ramp * (
                config.REDIS_WORKING_SET_INCIDENT_GB - config.REDIS_WORKING_SET_NORMAL_GB)
            cap = self.redis_memory_gb
            used = min(working_set, cap)
            if working_set <= cap * 0.95:
                hit_rate = config.REDIS_HIT_RATE_HEALTHY
                evictions = 0.0
            else:
                hit_rate = config.REDIS_HIT_RATE_HEALTHY * (cap / working_set) ** 4
                evictions = 1400 * (working_set / cap - 0.95)
            rps = config.BASE_RPS * traffic
            db_qps = rps * (1 - hit_rate) * 1.0
            demand = config.DB_BASE_CONNECTIONS + db_qps * config.DB_CONNECTIONS_PER_QPS
            db_conn = min(config.DB_MAX_CONNECTIONS, demand)
            oversub = max(0.0, demand / config.DB_MAX_CONNECTIONS - 1)
            latency = min(config.CHECKOUT_MAX_LATENCY_MS,
                          config.CHECKOUT_BASE_LATENCY_MS + (1 - hit_rate) * 60 + oversub * config.CHECKOUT_POOL_WAIT_FACTOR_MS)
            db_wait = max(0.0, latency - config.CHECKOUT_BASE_LATENCY_MS - (1 - hit_rate) * 60)
            # requests slower than the checkout timeout fail with 504
            timeout_errors = max(0.0, 1 - config.CHECKOUT_TIMEOUT_MS / latency) * 100
            return {
                "time": _iso(now),
                "traffic_multiplier": round(traffic, 2),
                "checkout-service": {
                    "requests_per_s": rps,
                    "p95_latency_ms": latency,
                    "cpu_percent": 18 + 6 * ramp,
                    "error_rate_percent": 0.1 + timeout_errors,
                    "replicas": 3,
                    "db_wait_ms": db_wait,
                },
                "redis-cache": {
                    "memory_gb": cap,
                    "used_memory_gb": used,
                    "memory_percent": 100 * used / cap,
                    "hit_rate_percent": 100 * hit_rate,
                    "evictions_per_s": evictions,
                    "cpu_percent": 8 + 30 * min(1.0, evictions / 1000),
                    "scaling": self.scaling_until is not None,
                    "scaling_target_gb": self.scaling_target_gb,
                },
                "postgres-db": {
                    "active_connections": db_conn,
                    "max_connections": config.DB_MAX_CONNECTIONS,
                    "connection_demand": demand,
                    "queries_per_s": db_qps,
                    "cpu_percent": 12 + 70 * min(1.0, db_conn / config.DB_MAX_CONNECTIONS) ** 2,
                    "avg_query_ms": 14 + 30 * min(1.0, db_conn / config.DB_MAX_CONNECTIONS) ** 3,
                },
            }

    @staticmethod
    def health(service: str, m: dict) -> str:
        """Return 'healthy' | 'degraded' | 'critical' for one service's metrics."""
        if service == "checkout-service":
            lat = m["p95_latency_ms"]
            return "critical" if lat > 3000 else "degraded" if lat > 800 else "healthy"
        if service == "redis-cache":
            if m["scaling"]:
                return "scaling"
            return "critical" if m["hit_rate_percent"] < 50 else "degraded" if m["memory_percent"] > 90 else "healthy"
        if service == "postgres-db":
            ratio = m["active_connections"] / m["max_connections"]
            return "critical" if ratio >= 0.98 else "degraded" if ratio > 0.8 else "healthy"
        return "healthy"

    # ---------------------------------------------------------------- history
    def _record(self, ts: float):
        """Store one noisy metric sample per service at timestamp ts."""
        snap = self.compute(ts)
        cutoff = ts - config.METRIC_HISTORY_MINUTES * 60
        for s in SERVICES:
            sample = {"time": _iso(ts), "ts": ts}
            for k, v in snap[s].items():
                if isinstance(v, bool) or v is None:
                    sample[k] = v
                elif k in ("memory_gb", "max_connections", "replicas"):
                    sample[k] = v
                else:
                    sample[k] = round(_noise(v), 2)
            self.history[s].append(sample)
            while self.history[s] and self.history[s][0]["ts"] < cutoff:
                self.history[s].popleft()

    def sample_loop(self):
        """Background loop: record a metric sample every METRIC_SAMPLE_INTERVAL_S."""
        while True:
            try:
                with self.lock:
                    self._record(time.time())
            except Exception:  # noqa: BLE001 - never kill the sampler
                log.exception("sampler failed")
            time.sleep(config.METRIC_SAMPLE_INTERVAL_S)

    # -------------------------------------------------------------- read APIs
    def state(self) -> dict:
        """Current state of all resources incl. health, for dashboards and the agent."""
        with self.lock:
            snap = self.compute()
            resources = []
            for s in SERVICES:
                m = {k: (round(v, 2) if isinstance(v, float) else v) for k, v in snap[s].items()}
                resources.append({"name": s, "health": self.health(s, snap[s]), "metrics": m})
            return {
                "time": snap["time"],
                "incident_active": self.incident_started_at is not None,
                "traffic_multiplier": snap["traffic_multiplier"],
                "resources": resources,
                "recent_events": [{k: v for k, v in e.items() if k != "ts"} for e in list(self.events)[-10:]],
            }

    def metrics(self, service: str, minutes: int = 15) -> list[dict]:
        """Time series of one service for the last `minutes` minutes."""
        with self.lock:
            cutoff = time.time() - minutes * 60
            return [{k: v for k, v in s.items() if k != "ts"} for s in self.history[service] if s["ts"] >= cutoff]

    def metrics_summary(self, service: str, minutes: int = 15) -> dict:
        """Compact summary (first/min/max/last per metric) - token friendly for the agent."""
        series = self.metrics(service, minutes)
        out = {"service": service, "window_minutes": minutes, "samples": len(series), "metrics": {}}
        if not series:
            return out
        for k, v in series[0].items():
            if k == "time" or not isinstance(v, (int, float)) or isinstance(v, bool):
                continue
            vals = [s[k] for s in series if isinstance(s.get(k), (int, float))]
            out["metrics"][k] = {"first": vals[0], "min": min(vals), "max": max(vals), "last": vals[-1]}
        return out

    def logs(self, service: str, limit: int = 30) -> list[str]:
        """Generate realistic log lines that match the current state of `service`."""
        snap = self.compute()
        m = snap[service]
        now = time.time()
        lines = []
        for i in range(limit):
            ts = datetime.fromtimestamp(now - (limit - i) * 1.7, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")[:-4] + "Z"
            lines.append(f"{ts} {self._log_line(service, m)}")
        return lines

    def _log_line(self, service: str, m: dict) -> str:
        """One random log line for a service given its current metrics."""
        rid = uuid.uuid4().hex[:8]
        if service == "checkout-service":
            lat = m["p95_latency_ms"]
            if lat > 1500 and random.random() < 0.7:
                total = int(_noise(lat))
                wait = int(_noise(m["db_wait_ms"]))
                return random.choice([
                    f"ERROR [checkout] req={rid} POST /checkout 504 - timeout after {config.CHECKOUT_TIMEOUT_MS}ms acquiring db connection (cache=MISS)",
                    f"ERROR [checkout] req={rid} POST /checkout 504 - timeout after {config.CHECKOUT_TIMEOUT_MS}ms acquiring db connection (cache=MISS)",
                    f"WARN  [checkout] req={rid} POST /checkout completed in {total}ms (db_pool_wait={wait}ms, cache=MISS)",
                    f"WARN  [checkout] req={rid} slow request: product lookup took {wait}ms waiting for db connection",
                    f"INFO  [hikari] pool=checkout-db active=100 idle=0 waiting={random.randint(40, 160)}",
                ])
            return random.choice([
                f"INFO  [checkout] req={rid} POST /checkout 200 in {int(_noise(lat))}ms (cache=HIT)",
                f"INFO  [checkout] req={rid} cart validated items={random.randint(1, 4)}",
                f"INFO  [checkout] req={rid} payment authorized provider=mockpay",
            ])
        if service == "redis-cache":
            if m["evictions_per_s"] > 50 and random.random() < 0.6:
                return random.choice([
                    f"WARN  [redis] used_memory={m['used_memory_gb']:.2f}G maxmemory={m['memory_gb']:g}G - evicting keys (allkeys-lru)",
                    f"INFO  [redis] evicted_keys/s={int(_noise(m['evictions_per_s']))} keyspace_hits_ratio={m['hit_rate_percent'] / 100:.2f}",
                    "WARN  [redis] OOM pressure: maxmemory reached, consider increasing maxmemory",
                ])
            if m["scaling"]:
                return f"INFO  [redis] resize in progress -> {m['scaling_target_gb']:g}G, replicating dataset"
            return random.choice([
                f"INFO  [redis] keyspace_hits_ratio={m['hit_rate_percent'] / 100:.2f} used_memory={m['used_memory_gb']:.2f}G",
                "INFO  [redis] background saving terminated with success",
                f"INFO  [redis] connected_clients={random.randint(20, 40)}",
            ])
        if service == "postgres-db":
            if m["active_connections"] >= m["max_connections"] * 0.98 and random.random() < 0.7:
                return random.choice([
                    "FATAL [postgres] sorry, too many clients already",
                    "FATAL [postgres] remaining connection slots are reserved for non-replication superuser connections",
                    f"LOG   [postgres] duration: {int(_noise(m['avg_query_ms']))} ms  statement: SELECT * FROM products WHERE sku = $1",
                    f"LOG   [postgres] duration: {int(_noise(m['avg_query_ms']))} ms  statement: SELECT price, stock FROM product_prices WHERE sku = $1",
                ])
            return random.choice([
                f"LOG   [postgres] duration: {int(_noise(m['avg_query_ms']))} ms  statement: INSERT INTO orders (...) VALUES (...)",
                "LOG   [postgres] checkpoint complete: wrote 412 buffers (2.5%)",
                f"LOG   [postgres] connection authorized: user=checkout database=shop (active={int(m['active_connections'])})",
            ])
        return "INFO  no logs"

    def traces(self, limit: int = 5) -> list[dict]:
        """Recent traces of POST /checkout with spans for cache, db pool and db query."""
        snap = self.compute()
        c, r, d = snap["checkout-service"], snap["redis-cache"], snap["postgres-db"]
        out = []
        for _ in range(limit):
            miss = random.random() > r["hit_rate_percent"] / 100
            total = _noise(c["p95_latency_ms"] if miss else config.CHECKOUT_BASE_LATENCY_MS)
            spans = [{"service": "checkout-service", "operation": "POST /checkout", "duration_ms": round(total)},
                     {"service": "redis-cache", "operation": "GET product:{sku}", "duration_ms": round(_noise(2.0), 1),
                      "result": "MISS" if miss else "HIT"}]
            if miss:
                wait = max(0.0, total - config.CHECKOUT_BASE_LATENCY_MS - d["avg_query_ms"])
                spans.append({"service": "postgres-db", "operation": "pool.acquire", "duration_ms": round(wait)})
                spans.append({"service": "postgres-db", "operation": "SELECT products/prices", "duration_ms": round(_noise(d["avg_query_ms"]))})
            spans.append({"service": "checkout-service", "operation": "payment.authorize", "duration_ms": round(_noise(120))})
            out.append({"trace_id": uuid.uuid4().hex[:16], "endpoint": "POST /checkout",
                        "duration_ms": round(total), "spans": spans})
        return out

    @staticmethod
    def service_graph() -> dict:
        """Static dependency graph of the shop."""
        return {
            "nodes": [
                {"id": "shop-frontend", "type": "web"},
                {"id": "checkout-service", "type": "service", "replicas": 3},
                {"id": "redis-cache", "type": "cache", "notes": "caches product + price lookups (read-through)"},
                {"id": "postgres-db", "type": "database", "notes": "source of truth for products, prices, orders"},
            ],
            "edges": [
                {"from": "shop-frontend", "to": "checkout-service", "protocol": "HTTP"},
                {"from": "checkout-service", "to": "redis-cache", "protocol": "RESP", "purpose": "product/price cache"},
                {"from": "checkout-service", "to": "postgres-db", "protocol": "SQL", "purpose": "cache misses + orders"},
            ],
        }

    def checkout_latency_ms(self) -> float:
        """Current (noisy) checkout latency used by POST /api/checkout."""
        return _noise(self.compute()["checkout-service"]["p95_latency_ms"])


infra = Infrastructure()

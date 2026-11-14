"""
config.py - Central configuration for the AI SRE demo backend.

All tunable numbers of the simulated infrastructure and the agent live here,
so the demo can be adjusted (e.g. "make the incident worse", "scale faster")
without touching the logic files.

Values can be overridden via environment variables (see .env.example).
"""

import os

from dotenv import load_dotenv

load_dotenv()

# --- Gemini / Agent ---------------------------------------------------------
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
# Check the exact model id in AI Studio (model picker) and override via .env
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-3.7-flash")
# "gemini" = real agent, "mock" = scripted agent (no key needed, demo-safe)
AGENT_MODE = os.getenv("AGENT_MODE", "gemini" if GEMINI_API_KEY else "mock")
# If the real agent fails mid-demo, fall back to the scripted run
AGENT_FALLBACK_TO_MOCK = os.getenv("AGENT_FALLBACK_TO_MOCK", "true").lower() == "true"
AGENT_MAX_STEPS = int(os.getenv("AGENT_MAX_STEPS", "12"))
# Delay between scripted (mock) agent steps, in seconds
MOCK_STEP_DELAY_S = float(os.getenv("MOCK_STEP_DELAY_S", "1.4"))

# --- Traffic ----------------------------------------------------------------
BASE_RPS = 50                 # checkout requests per second, normal day
INCIDENT_TRAFFIC_MULTIPLIER = 10
START_IN_INCIDENT = True      # demo starts on Black Friday (checkout already failing)
INCIDENT_STARTED_MINUTES_AGO = 8
INCIDENT_RAMP_S = 5           # seconds until Black Friday traffic is at full level

# --- Redis cache ------------------------------------------------------------
REDIS_DEFAULT_MEMORY_GB = 4
REDIS_WORKING_SET_NORMAL_GB = 2.8     # cache data needed on a normal day
REDIS_WORKING_SET_INCIDENT_GB = 6.5   # cache data needed on Black Friday
REDIS_HIT_RATE_HEALTHY = 0.95
REDIS_SCALE_DURATION_S = 15           # how long "Scaling..." takes in the demo

# --- Postgres ---------------------------------------------------------------
DB_MAX_CONNECTIONS = 100
DB_BASE_CONNECTIONS = 8
DB_CONNECTIONS_PER_QPS = 0.35

# --- Checkout latency model -------------------------------------------------
CHECKOUT_BASE_LATENCY_MS = 280
CHECKOUT_POOL_WAIT_FACTOR_MS = 16000  # extra latency per 100% over-subscription
CHECKOUT_MAX_LATENCY_MS = 12000
CHECKOUT_MAX_REAL_SLEEP_S = 10        # cap for POST /api/checkout real waiting
CHECKOUT_TIMEOUT_MS = 3000            # checkout gives up after this -> HTTP 504

# --- Metric history ---------------------------------------------------------
METRIC_SAMPLE_INTERVAL_S = 2
METRIC_HISTORY_MINUTES = 30
NOISE = 0.04                          # +-4% random noise on metrics

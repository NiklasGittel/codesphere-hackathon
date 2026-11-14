# Backend – simulierte Infrastruktur + Gemini AI SRE

Simuliert `checkout-service → redis-cache (4 GB) → postgres-db` für den Tech-Europe-Merch-Shop.
Bei „Black Friday“ läuft Redis voll, die Hit-Rate bricht ein, Postgres läuft über, der Checkout dauert ca. 10 s.
Der Gemini-Agent findet die Ursache und schlägt „Redis auf 8 GB skalieren“ vor. Ein Mensch klickt auf Approve, danach ist der Checkout wieder bei ca. 0,3 s.

## Starten (Windows, PowerShell)

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
copy .env.example .env      # dann GEMINI_API_KEY in .env eintragen
uvicorn main:app --reload --port 8080
```

API-Doku zum Durchklicken: http://localhost:8080/docs

Ohne Key läuft der Agent im **Mock-Modus** (`AGENT_MODE=mock`): ein Skript, das echte Tool-Daten nutzt. Das ist auch der automatische Fallback, falls Gemini in der Demo hängt.

## Endpunkte

| Methode | Pfad | Zweck |
|---|---|---|
| GET | `/api/infra/state` | Alle Ressourcen mit `health` (healthy/degraded/critical/scaling), Metriken, Events |
| GET | `/api/metrics?service=redis-cache&minutes=15` | Zeitreihe für Charts |
| GET | `/api/logs?service=postgres-db&limit=30` | Log-Zeilen |
| GET | `/api/traces/checkout?limit=5` | Traces mit Spans |
| GET | `/api/service-graph` | Abhängigkeitsgraph |
| POST | `/api/checkout` | Kaufen, wartet so lange, wie die Infrastruktur langsam ist |
| POST | `/api/incident/start` | Black Friday starten (Traffic steigt über 20 s auf ×10) |
| POST | `/api/reset` | Normalzustand |
| GET/POST | `/api/agent/investigate` | Agent-Schritte als Server-Sent Events |
| GET | `/api/agent/pending` | Vorgeschlagene Aktion |
| POST | `/api/agent/approve` | `{"action_id":"..."}`: Aktion ausführen |
| POST | `/api/actions/scale` | Manuell skalieren `{"resource":"redis-cache","memory_gb":8}` |

Services: `checkout-service`, `redis-cache`, `postgres-db`

### Agent-Events (SSE, jede Zeile `data: {...}`)

```json
{"type":"start","mode":"gemini","model":"..."}
{"type":"thought","text":"Checking checkout metrics..."}
{"type":"tool_call","step":3,"tool":"query_metrics","args":{"service":"checkout-service"}}
{"type":"tool_result","step":3,"tool":"query_metrics","summary":"p95_latency_ms: 283 → 9797, ...","result":{}}
{"type":"root_cause","summary":"...","chain":["Traffic x10","Redis memory 100%", "..."],"evidence":["..."],
 "proposed_action":{"id":"fe279341","resource":"redis-cache","action":"scale_memory","params":{"memory_gb":8}}}
{"type":"done"}
```

Frontend-Beispiel:

```js
const es = new EventSource(`${API}/api/agent/investigate`);
es.onmessage = (e) => { const ev = JSON.parse(e.data); if (ev.type === "done") es.close(); /* render */ };
```

## Demo-Ablauf

1. `POST /api/reset` → Checkout ca. 0,3 s
2. `POST /api/incident/start` → nach ca. 20 s Checkout ca. 10 s
3. Agent starten → Root Cause und Vorschlag
4. Approve → 15 s „scaling“ → alles wieder grün

Alle Stellschrauben (Dauer, Latenzen, Scaling-Zeit) stehen in `config.py`.

## Deploy auf Cloud Run (optional)

```powershell
gcloud run deploy ai-sre-backend --source . --region europe-west1 --allow-unauthenticated --max-instances 1 `
  --set-env-vars GEMINI_API_KEY=DEIN_KEY,GEMINI_MODEL=gemini-3.1-pro-preview
```

Wichtig: Cloud Run kann mehrere Instanzen starten, und der Zustand liegt im Speicher. Deshalb steht `--max-instances 1` im Befehl.

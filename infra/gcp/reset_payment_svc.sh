#!/usr/bin/env bash
# Rehearsal reset: send 100 % of traffic back to the faulty revision v482.
set -euo pipefail
PROJECT="${PROJECT:?set PROJECT=<gcp-project-id>}"
REGION="${REGION:-europe-west3}"
SERVICE="${SERVICE:-payment-svc}"
# Bad revision: LIVE_BAD_REVISION from backend/.env if set, else <service>-v482
ENV_FILE="$(dirname "$0")/../../backend/.env"
BAD="$(grep -E '^LIVE_BAD_REVISION=' "$ENV_FILE" 2>/dev/null | tail -1 | cut -d= -f2)"
BAD="${BAD:-${SERVICE}-v482}"
gcloud run services update-traffic "$SERVICE" --project "$PROJECT" --region "$REGION" \
  --to-revisions "${BAD}=100" --quiet
echo "Reset: 100 % traffic on ${BAD} (the bad deploy)."

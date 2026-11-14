#!/usr/bin/env bash
# Deploys payment-svc to Cloud Run with two revisions:
#   payment-svc-v481  healthy  (~30 ms)
#   payment-svc-v482  "bad deploy": every request takes ~11 s (> shop deadline of 8 s) -> 100 % traffic
#
# Usage (after `gcloud auth login`):  PROJECT=my-project ./infra/gcp/deploy_payment_svc.sh
set -euo pipefail
PROJECT="${PROJECT:?set PROJECT=<gcp-project-id>}"
REGION="${REGION:-europe-west3}"
SERVICE="${SERVICE:-payment-svc}"
SRC="$(cd "$(dirname "$0")/payment-svc" && pwd)"

gcloud config set project "$PROJECT" >/dev/null
if [[ "${NO_BUILD:-0}" == "1" ]]; then
  gcloud services enable run.googleapis.com
else
  gcloud services enable run.googleapis.com cloudbuild.googleapis.com artifactregistry.googleapis.com
fi

COMMON=(--region "$REGION" --allow-unauthenticated
        --min-instances 1 --max-instances 3 --cpu 1 --memory 256Mi --quiet)
EXTRA_ENV=""
if [[ "${NO_BUILD:-0}" == "1" ]]; then
  # No Cloud Build / Artifact Registry: run the public Python image and pass the
  # service code in an env var (works in restricted lab projects).
  CODE_B64="$(base64 < "$SRC/main.py" | tr -d '\n')"
  COMMON+=(--image docker.io/library/python:3.12-slim --command sh
           --args "-c,echo \$APP_B64 | base64 -d > /tmp/main.py && exec python /tmp/main.py")
  EXTRA_ENV=",APP_B64=$CODE_B64"
else
  COMMON+=(--source "$SRC")
fi

echo "1/2 Deploying healthy release 481 (first build takes ~2-3 min)..."
gcloud run deploy "$SERVICE" "${COMMON[@]}" --revision-suffix v481 \
  --set-env-vars "RELEASE=481,FAULT_DELAY_MS=0,FAULT_ERROR_RATE=0$EXTRA_ENV"

echo "2/2 Deploying faulty release 482 (takes 100% traffic)..."
gcloud run deploy "$SERVICE" "${COMMON[@]}" --revision-suffix "${BAD_SUFFIX:-v482}" \
  --set-env-vars "RELEASE=482,FAULT_DELAY_MS=${BAD_DELAY_MS:-11000},FAULT_ERROR_RATE=${BAD_ERROR_RATE:-0}$EXTRA_ENV"

URL="$(gcloud run services describe "$SERVICE" --region "$REGION" --format='value(status.url)')"
echo
echo "Service: $URL"
echo "Try:     curl -s $URL/authorize"
echo "Put into backend/.env:"
echo "  LIVE_GCP_PROJECT=$PROJECT"
echo "  LIVE_GCP_REGION=$REGION"
echo "  LIVE_RUN_SERVICE=$SERVICE"

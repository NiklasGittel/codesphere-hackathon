#!/usr/bin/env bash
# Creates a tiny Cloud SQL Postgres instance (10 GB, auto-grow OFF) and fills
# it to ~85% so Stratus can detect "disk almost full" and fix it by growing the disk.
#
# Usage (on your machine, after `gcloud auth login`):
#   PROJECT=my-project ./infra/gcp/setup_cloudsql.sh
# Needs: gcloud, psql (brew install libpq && brew link --force libpq)
set -euo pipefail

PROJECT="${PROJECT:?set PROJECT=<gcp-project-id>}"
REGION="${REGION:-europe-west3}"
INSTANCE="${INSTANCE:-stratus-orders-db}"
DB="orders"
DB_PASS="${DB_PASS:-$(openssl rand -hex 16)}"
TARGET_GB="${TARGET_GB:-7.6}"   # data size to reach (~85% of 10 GB incl. WAL/system overhead)

gcloud config set project "$PROJECT" >/dev/null
gcloud services enable sqladmin.googleapis.com

if ! gcloud sql instances describe "$INSTANCE" >/dev/null 2>&1; then
  echo "Creating $INSTANCE (takes ~5-10 min)..."
  gcloud sql instances create "$INSTANCE" \
    --database-version=POSTGRES_16 --edition=ENTERPRISE --tier=db-f1-micro \
    --region="$REGION" --storage-type=SSD --storage-size=10GB \
    --no-storage-auto-increase --no-backup \
    --root-password="$DB_PASS"
  gcloud sql databases create "$DB" --instance="$INSTANCE"
  echo "$DB_PASS" > "$(dirname "$0")/.db_password"   # gitignored
fi
DB_PASS="$(cat "$(dirname "$0")/.db_password")"

# Allow this machine's IP for the fill (removed again at the end).
MY_IP="$(curl -s https://api.ipify.org)"
gcloud sql instances patch "$INSTANCE" --authorized-networks="$MY_IP/32" --quiet
HOST="$(gcloud sql instances describe "$INSTANCE" --format='value(ipAddresses[0].ipAddress)')"
export PGPASSWORD="$DB_PASS"
PSQL=(psql "host=$HOST user=postgres dbname=$DB sslmode=require" -v ON_ERROR_STOP=1 -qtA)

"${PSQL[@]}" -f "$(dirname "$0")/fill.sql"
echo "Filling in batches until ${TARGET_GB} GB (each batch ~1 GB, a few minutes each)..."
while true; do
  SIZE_GB="$("${PSQL[@]}" -c "select round(pg_database_size('$DB')/1024.0^3, 2)")"
  echo "  orders db size: ${SIZE_GB} GB"
  awk "BEGIN{exit !($SIZE_GB >= $TARGET_GB)}" && break
  "${PSQL[@]}" -c "select fill_batch(1000000)"
  "${PSQL[@]}" -c "checkpoint" >/dev/null 2>&1 || true
done

gcloud sql instances patch "$INSTANCE" --clear-authorized-networks --quiet
echo
echo "Done. Instance: $INSTANCE  host: $HOST  disk: 10 GB, data: ${SIZE_GB} GB"
echo "Fix (what the agent does after approval):"
echo "  gcloud sql instances patch $INSTANCE --storage-size=20GB"
echo "Delete tonight:  gcloud sql instances delete $INSTANCE"

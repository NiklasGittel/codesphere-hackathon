#!/usr/bin/env bash
# Makes fresh "almost full" copies of the filled demo database.
# Each clone is an independent instance at 10 GB / ~85 % used / auto-grow off.
#
# Usage:  PROJECT=my-project ./infra/gcp/clone.sh 3        -> stratus-orders-db-1..3
#         PROJECT=my-project ./infra/gcp/clone.sh delete    -> delete all clones
set -euo pipefail

PROJECT="${PROJECT:?set PROJECT=<gcp-project-id>}"
SOURCE="${SOURCE:-stratus-orders-db}"
ARG="${1:-1}"
gcloud config set project "$PROJECT" >/dev/null

if [[ "$ARG" == "delete" ]]; then
  for i in $(gcloud sql instances list --filter="name~^${SOURCE}-[0-9]+$" --format='value(name)'); do
    echo "Deleting $i"; gcloud sql instances delete "$i" --quiet --async
  done
  exit 0
fi

# Next free numbers after the existing clones.
LAST=$(gcloud sql instances list --filter="name~^${SOURCE}-[0-9]+$" --format='value(name)' \
  | sed "s/^${SOURCE}-//" | sort -n | tail -1)
START=$(( ${LAST:-0} + 1 ))

for (( n=START; n<START+ARG; n++ )); do
  TARGET="${SOURCE}-${n}"
  echo "Cloning $SOURCE -> $TARGET"
  gcloud sql instances clone "$SOURCE" "$TARGET"
  # Make sure Cloud SQL can't "fix" the disk before Stratus does.
  gcloud sql instances patch "$TARGET" --no-storage-auto-increase --quiet
  gcloud sql instances describe "$TARGET" \
    --format='value(name,settings.dataDiskSizeGb,settings.storageAutoResize)'
done

echo
echo "Never resize the source ($SOURCE). It is the template for new copies."
echo "Delete all copies tonight:  PROJECT=$PROJECT ./infra/gcp/clone.sh delete"

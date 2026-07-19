#!/usr/bin/env bash
# Produces a SealedSecret manifest for one of Sapfire Manager's secret sets,
# without ever writing the plaintext Secret to disk or to git — see
# README.md "Secrets". Requires `kubeseal` and a cluster with the Sealed
# Secrets controller already installed and reachable (kubeseal talks to it,
# either in-cluster via kubeconfig or via --cert against a fetched public key).
#
# Usage:
#   ./seal-secret.sh <namespace> <secret-name> <KEY=value> [<KEY=value> ...]
#
# Example (see README.md for the full list of required secret names/keys):
#   ./seal-secret.sh sapfire-dev sapfire-db-credentials APP_DB_PASSWORD='...' \
#     > overlays/dev/sealed-secrets/sapfire-db-credentials.yaml
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <namespace> <secret-name> <KEY=value> [<KEY=value> ...]" >&2
  exit 1
fi

namespace=$1
name=$2
shift 2

literal_args=()
for kv in "$@"; do
  literal_args+=(--from-literal="$kv")
done

kubectl create secret generic "$name" \
  --namespace "$namespace" \
  "${literal_args[@]}" \
  --dry-run=client -o yaml \
  | kubeseal --format yaml --namespace "$namespace"

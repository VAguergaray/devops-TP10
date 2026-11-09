#!/bin/bash

set -euo pipefail

CHART="./devops-portfolio"
OUTPUT_DIR="/tmp/helm-render-test"

echo "========================================"
echo " TP10C - RENDER FIRST, DEPLOY SECOND"
echo "========================================"

mkdir -p "$OUTPUT_DIR"

validate_environment() {
    local ENVIRONMENT="$1"
    local VALUES_FILE="$2"
    local OUTPUT_FILE="$OUTPUT_DIR/${ENVIRONMENT}.yaml"

    echo ""
    echo "========================================"
    echo "Validando entorno: $ENVIRONMENT"
    echo "========================================"

    echo "[1/4] Helm lint..."
    helm lint "$CHART" -f "$VALUES_FILE"

    echo "[2/4] Renderizando manifiestos..."
    helm template "notes-${ENVIRONMENT}" "$CHART" \
        --namespace "$ENVIRONMENT" \
        -f "$VALUES_FILE" > "$OUTPUT_FILE"

    echo "[3/4] Validando YAML..."
    python3 - "$OUTPUT_FILE" <<'PY'
import sys
import yaml

file_path = sys.argv[1]

with open(file_path, encoding="utf-8") as file:
    documents = list(yaml.safe_load_all(file))

documents = [doc for doc in documents if doc is not None]

if not documents:
    raise SystemExit("ERROR: No se generaron manifiestos YAML.")

for index, document in enumerate(documents, start=1):
    if not isinstance(document, dict):
        raise SystemExit(f"ERROR: Documento {index} no es válido.")

    if "apiVersion" not in document or "kind" not in document:
        raise SystemExit(f"ERROR: Documento {index} incompleto.")

print(f"YAML OK: {len(documents)} recursos encontrados.")
PY

    echo "[4/4] Kubernetes dry-run..."
    kubectl apply --dry-run=client -f "$OUTPUT_FILE"

    echo "ENTORNO $ENVIRONMENT: OK"
}

validate_environment "staging" "$CHART/values-staging.yaml"
validate_environment "production" "$CHART/values-prod.yaml"

echo ""
echo "========================================"
echo " TP10C: TODAS LAS VALIDACIONES OK"
echo "========================================"

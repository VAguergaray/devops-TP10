#!/bin/bash

set -uo pipefail

ERRORS=0

ok() {
    echo "[OK] $1"
}

fail() {
    echo "[FAIL] $1"
    ERRORS=$((ERRORS + 1))
}

echo "=========================================="
echo " TP10B - HELM RENDER FIRST VALIDATE SECOND"
echo "=========================================="

echo ""
echo "--- 1. Helm Lint ---"

if helm lint ./devops-portfolio; then
    ok "Helm Chart validado"
else
    fail "Error en Helm Lint"
fi

echo ""
echo "--- 2. Renderizado de produccion ---"

if helm template test-release ./devops-portfolio \
-f values-prod.yaml > /tmp/test-rendered.yaml; then
    ok "Renderizado completado"
else
    fail "Error al renderizar Helm"
fi

echo ""
echo "--- 3. Validacion YAML ---"

if python3 -c "import yaml; list(yaml.safe_load_all(open('/tmp/test-rendered.yaml')))"; then
    ok "Sintaxis YAML correcta"
else
    fail "Error de sintaxis YAML"
fi

echo ""
echo "--- 4. Validacion Kubernetes ---"

if kubectl apply --dry-run=client -f /tmp/test-rendered.yaml; then
    ok "Manifiestos Kubernetes aceptados"
else
    fail "Error en validacion Kubernetes"
fi

echo ""
echo "=========================================="

if [ "$ERRORS" -eq 0 ]; then
    echo "TP10B OK: Todas las validaciones pasaron"
else
    echo "ATENCION: $ERRORS validaciones fallaron"
fi

echo "=========================================="

exit "$ERRORS"

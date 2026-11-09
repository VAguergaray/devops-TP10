#!/bin/bash
set -euo pipefail

echo "=========================================="
echo " TP10C - VERIFICACION HELM MULTI-ENTORNO"
echo "=========================================="

verificar_entorno() {
    local ENV="$1"
    local NAMESPACE="$2"
    local RELEASE="$3"

    echo ""
    echo ">>> Verificando $ENV ($NAMESPACE)"

    helm status "$RELEASE" -n "$NAMESPACE" >/dev/null
    echo "[OK] Helm Release: $RELEASE"

    for DEPLOYMENT in backend frontend postgres; do
        kubectl rollout status deployment/"$DEPLOYMENT" \
            -n "$NAMESPACE" --timeout=120s
        echo "[OK] Deployment $DEPLOYMENT"
    done

    kubectl get pods -n "$NAMESPACE"

    PVC_STATUS=$(kubectl get pvc postgres-pvc \
        -n "$NAMESPACE" \
        -o jsonpath='{.status.phase}')

    if [ "$PVC_STATUS" != "Bound" ]; then
        echo "[ERROR] PVC no está Bound en $NAMESPACE"
        return 1
    fi

    echo "[OK] PVC postgres-pvc: Bound"

    if [ "$ENV" = "production" ]; then
        kubectl get hpa backend-hpa -n "$NAMESPACE" >/dev/null
        echo "[OK] HPA backend-hpa creado"
    fi

    echo "[OK] Entorno $ENV verificado"
}

verificar_entorno "staging" "staging-tp10c" "notes-staging"
verificar_entorno "production" "production-tp10c" "notes-production"

echo ""
echo "=========================================="
echo " TP10C: TODAS LAS VERIFICACIONES OK"
echo "=========================================="

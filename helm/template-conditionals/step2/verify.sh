#!/bin/bash

# both releases must exist
helm -n prod-ns status mock-app-prod >/dev/null 2>&1 || exit 1
helm -n dev-ns status mock-app-dev >/dev/null 2>&1 || exit 1

# prod gets an HPA, dev does not
PROD=$(kubectl get hpa -n prod-ns --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
DEV=$(kubectl get hpa -n dev-ns --no-headers 2>/dev/null | wc -l | tr -d '[:space:]')
[ "$PROD" -ge 1 ] || exit 1
[ "$DEV" == "0" ] || exit 1

# and it must come from a condition in the template, not from the HPA template
# having simply been deleted - re-render both ways and check it flips
command -v helm >/dev/null 2>&1 || exit 1
RENDER_PROD=$(helm template verifycheck /charts/mock-app --set environment=prod 2>/dev/null | grep -c "HorizontalPodAutoscaler")
RENDER_DEV=$(helm template verifycheck /charts/mock-app --set environment=dev 2>/dev/null | grep -c "HorizontalPodAutoscaler")
[ "$RENDER_PROD" -ge 1 ] || exit 1
[ "$RENDER_DEV" == "0" ] || exit 1

exit 0

#!/bin/bash
LOG=/root/.check
STEP="Step 4 · One CA, every namespace that asked"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }
R=""

for _ in $(seq 1 12); do
  SYNCED=$(kubectl get bundle lab-ca-bundle \
    -o jsonpath='{.status.conditions[?(@.type=="Synced")].status}' 2>/dev/null)
  BMSG=$(kubectl get bundle lab-ca-bundle \
    -o jsonpath='{.status.conditions[?(@.type=="Synced")].message}' 2>/dev/null)
  [ -n "$SYNCED" ] || { R="nobundle"; sleep 5; continue; }
  [ "$SYNCED" == "True" ] || { R="notsynced"; sleep 5; continue; }

  for NS in app client; do
    kubectl -n "$NS" get configmap lab-ca-bundle >/dev/null 2>&1 || { R="missing:$NS"; break; }
  done
  case "$R" in missing:*) sleep 5; continue ;; esac

  KEY=$(kubectl -n client get configmap lab-ca-bundle \
    -o jsonpath='{.data.root-ca\.pem}' 2>/dev/null)
  [ -n "$KEY" ] || { R="wrongkey"; sleep 5; continue; }
  echo "$KEY" | grep -q "BEGIN CERTIFICATE" || { R="notacert"; sleep 5; continue; }

  # Scoping is the point of the selector: a Bundle that went everywhere would
  # satisfy every check above and teach the opposite lesson.
  if kubectl -n default get configmap lab-ca-bundle >/dev/null 2>&1; then
    R="toobroad"; break
  fi

  AVAIL=$(kubectl -n client get deploy client \
    -o jsonpath='{.status.availableReplicas}' 2>/dev/null)
  [ "${AVAIL:-0}" -ge 1 ] 2>/dev/null || { R="noclient"; sleep 5; continue; }

  BODY=$(kubectl -n client exec deploy/client -- \
    curl -s --max-time 10 --cacert /etc/trust/root-ca.pem \
    https://web.app.svc.cluster.local:8443/ 2>/dev/null)
  echo "$BODY" | grep -q "web, in namespace app" || { R="curlfail"; sleep 5; continue; }

  pass
done

case "$R" in
  nobundle) fail \
    "There is no Bundle called 'lab-ca-bundle'." \
    "" \
    "  kubectl get bundle" \
    "  kubectl explain bundle.spec" ;;
  notsynced) fail \
    "Bundle 'lab-ca-bundle' is not Synced (Synced=${SYNCED:-<none>})." \
    "" \
    "What it says:" \
    "  ${BMSG:-<no message>}" \
    "" \
    "A Bundle is cluster-scoped, so it reads its sources from trust-manager's own" \
    "trust namespace -- the same namespace a ClusterIssuer reads from, for the same" \
    "reason. The source Secret has to be there, and the key has to be the" \
    "certificate rather than the key." ;;
  missing:*) fail \
    "The ConfigMap 'lab-ca-bundle' has not appeared in namespace '${R#missing:}'." \
    "" \
    "  kubectl get namespace --show-labels" \
    "  kubectl get configmap -A | grep lab-ca-bundle" \
    "" \
    "The Bundle writes only into namespaces its selector matches, so a namespace" \
    "joins by being labelled. Both app and client need the label." ;;
  wrongkey) fail \
    "The distributed ConfigMap has no key called 'root-ca.pem'." \
    "" \
    "  kubectl -n client get configmap lab-ca-bundle -o jsonpath='{.data}' | tr ',' '\\n' | cut -d'\"' -f2" \
    "" \
    "target.configMap.key names the filename the bundle lands as, and" \
    "/root/client.yaml mounts it expecting that name." ;;
  notacert) fail \
    "The key 'root-ca.pem' exists but does not contain a PEM certificate." \
    "" \
    "  kubectl -n client get configmap lab-ca-bundle -o jsonpath='{.data.root-ca\\.pem}' | head -3" ;;
  toobroad) fail \
    "The bundle reached namespace 'default', which was not asked for." \
    "" \
    "  kubectl get configmap -A | grep lab-ca-bundle" \
    "" \
    "The task is a Bundle scoped to namespaces labelled trust=lab. A selector that" \
    "matches everything distributes the CA to workloads nobody decided should" \
    "trust it -- which is the difference between trust being granted and trust" \
    "being assumed." ;;
  noclient) fail \
    "The client Deployment in namespace client has no available replicas." \
    "" \
    "  kubectl apply -f /root/client.yaml" \
    "  kubectl -n client get pods" \
    "" \
    "It mounts the ConfigMap the Bundle creates, so it cannot start until that" \
    "ConfigMap exists in its namespace." ;;
  curlfail) fail \
    "The client Pod could not verify the web Service using the distributed bundle." \
    "" \
    "  response: ${BODY:-<nothing>}" \
    "" \
    "  kubectl -n client exec deploy/client -- ls -l /etc/trust" \
    "  kubectl -n client exec deploy/client -- curl -sS --cacert /etc/trust/root-ca.pem https://web.app.svc.cluster.local:8443/" \
    "" \
    "If the file is there, check the web Service is still up and reachable across" \
    "the namespace boundary:" \
    "  kubectl -n app get pods,svc -l app=web" \
    "  kubectl -n client exec deploy/client -- curl -skI https://web.app.svc.cluster.local:8443/" ;;
  *) fail "Unexpected state -- rerun the check." ;;
esac

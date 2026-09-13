#!/bin/bash
#
# Every exit path below says why. Killercoda only reads the exit code, so the
# explanation is written to /root/.check and the learner reads it with `why`.
LOG=/root/.check
STEP="Step 3 · Renewal the Gateway never hears about"
: > "$LOG"
fail() { { echo "x $STEP"; echo; printf '%s\n' "$@"; } | tee "$LOG"; exit 1; }
pass() { echo "OK $STEP -- passed." | tee "$LOG"; exit 0; }

GWIP=$(kubectl -n envoy-gateway-system get svc \
  -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
  -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
[ -n "$GWIP" ] || fail \
  "Envoy Gateway has not created a data-plane Service for 'web-gateway'." \
  "" \
  "  kubectl -n envoy-gateway-system get pods,svc"

# step1 recorded the certificate's original serial the moment it first went
# live. Without that, a fresh-from-step-1 certificate and a genuinely
# renewed one are indistinguishable -- both are "recent" by any time-based
# check, since step 1 only just finished.
[ -f /root/.secure-cert-original-serial ] || fail \
  "The original certificate's serial was never recorded, so a renewal cannot be detected." \
  "" \
  "That file is written when step 1's check passes. Go back and pass step 1" \
  "first -- without a 'before' there is no way to tell a renewed certificate" \
  "from the one step 1 issued minutes ago."

ORIGINAL_SERIAL=$(cat /root/.secure-cert-original-serial)
CURRENT_SERIAL=$(kubectl get secret secure-cert-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
  | base64 -d | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
[ -n "$CURRENT_SERIAL" ] && [ "$CURRENT_SERIAL" != "$ORIGINAL_SERIAL" ] || fail \
  "The Secret still holds the same certificate step 1 issued." \
  "" \
  "  serial now:       ${CURRENT_SERIAL:-<none>}" \
  "  serial at step 1: $ORIGINAL_SERIAL" \
  "" \
  "Renewal is cert-manager's job, not the Gateway's -- ask it to reissue and" \
  "watch the Secret's contents change underneath everything:" \
  "  kubectl describe certificate secure-cert | tail -20" \
  "  kubectl get secret secure-cert-tls -o jsonpath='{.data.tls\\.crt}' \\" \
  "    | base64 -d | openssl x509 -noout -serial -dates"

# No object anywhere in the Gateway/Envoy chain should have needed touching.
ENVOY_RESTARTS=$(kubectl -n envoy-gateway-system get pods -l gateway.envoyproxy.io/owning-gateway-name=web-gateway \
  -o jsonpath='{.items[0].status.containerStatuses[0].restartCount}' 2>/dev/null)
[ "$ENVOY_RESTARTS" == "0" ] || fail \
  "The Envoy Pod has restarted ${ENVOY_RESTARTS} time(s)." \
  "" \
  "The finding this step is after is that nothing had to be restarted: the" \
  "Secret changed and Envoy picked it up on its own. Restarting the data plane" \
  "by hand proves the opposite, and hides whether it would have worked." \
  "" \
  "Restore the lab to a Gateway that was never touched -- delete and recreate" \
  "it, then renew again without intervening."

for _ in $(seq 1 20); do
  SERVED_SERIAL=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername secure.example.com 2>/dev/null \
    | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)
  SECRET_SERIAL=$(kubectl get secret secure-cert-tls -o jsonpath='{.data.tls\.crt}' 2>/dev/null \
    | base64 -d | openssl x509 -noout -serial 2>/dev/null | cut -d= -f2)

  # What Envoy actually hands out on the wire has to match what's in the
  # Secret right now -- proof the new keypair, not a cached old one, is live.
  [ -n "$SERVED_SERIAL" ] && [ "$SERVED_SERIAL" == "$SECRET_SERIAL" ] && pass
  sleep 5
done

fail \
  "The certificate was renewed, but Envoy is still serving the old one." \
  "" \
  "  serial on the wire:    ${SERVED_SERIAL:-<no certificate>}" \
  "  serial in the Secret:  ${SECRET_SERIAL:-<none>}" \
  "" \
  "Envoy Gateway watches the Secret and pushes the new keypair down without any" \
  "object in the Gateway chain being edited -- but it is not instantaneous." \
  "Give it a few more seconds and press CHECK again. If it stays behind, look" \
  "for the controller rejecting the new Secret:" \
  "  kubectl -n envoy-gateway-system logs deploy/envoy-gateway --tail=30"

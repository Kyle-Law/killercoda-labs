#!/bin/bash

for _ in $(seq 1 30); do
  READY=$(kubectl get certificate secure-cert -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
  [ "$READY" == "True" ] || { sleep 5; continue; }

  PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="https")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$PROG" == "True" ] || { sleep 5; continue; }

  # The listener has to be referencing THIS Secret, not just any TLS Secret --
  # otherwise a listener pointed at an unrelated cert would still pass.
  SECRET_REF=$(kubectl get gateway web-gateway \
    -o jsonpath='{.spec.listeners[?(@.name=="https")].tls.certificateRefs[0].name}' 2>/dev/null)
  [ "$SECRET_REF" == "secure-cert-tls" ] || { sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { sleep 5; continue; }

  # Independently re-derive the served cert's SAN and issuer, rather than
  # trusting anything the learner's own helper reported.
  SERVED=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername secure.example.com 2>/dev/null \
    | openssl x509 -noout -issuer -ext subjectAltName -serial 2>/dev/null)
  echo "$SERVED" | grep -q "CN=lab-root-ca" || { sleep 5; continue; }
  echo "$SERVED" | grep -q "DNS:secure.example.com" || { sleep 5; continue; }

  ANSWER=$(curl -s --cacert /root/ca.crt --resolve "secure.example.com:443:$GWIP" \
    "https://secure.example.com/hostname" 2>/dev/null)
  WEBPOD=$(kubectl get pod -l app=web --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

  if [ -n "$ANSWER" ] && [ "$ANSWER" == "$WEBPOD" ]; then
    # Recorded once, for step 3 to prove a later reissuance actually changed
    # something -- a "was it renewed" check has nothing to compare against
    # without knowing what the certificate looked like to begin with.
    echo "$SERVED" | grep -oE 'serial=.*' | cut -d= -f2 > /root/.secure-cert-original-serial
    exit 0
  fi
  sleep 5
done

exit 1

#!/bin/bash

for _ in $(seq 1 30); do
  LISTENERS=$(kubectl get gateway web-gateway -o jsonpath='{.spec.listeners[*].name}' 2>/dev/null)
  echo "$LISTENERS" | grep -qw https-secure && echo "$LISTENERS" | grep -qw https-other || { sleep 5; continue; }

  SEC_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="https-secure")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  OTH_PROG=$(kubectl get gateway web-gateway \
    -o jsonpath='{.status.listeners[?(@.name=="https-other")].conditions[?(@.type=="Programmed")].status}' 2>/dev/null)
  [ "$SEC_PROG" == "True" ] && [ "$OTH_PROG" == "True" ] || { sleep 5; continue; }

  GWIP=$(kubectl -n envoy-gateway-system get svc \
    -l gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=web-gateway \
    -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null)
  [ -n "$GWIP" ] || { sleep 5; continue; }

  # Independently re-derive which SAN each SNI name actually gets, rather than
  # trusting configuration alone -- the two certs must differ from each other.
  SECURE_SAN=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername secure.example.com 2>/dev/null \
    | openssl x509 -noout -ext subjectAltName 2>/dev/null)
  OTHER_SAN=$(echo | timeout 5 openssl s_client -connect "$GWIP:443" -servername other.example.com 2>/dev/null \
    | openssl x509 -noout -ext subjectAltName 2>/dev/null)
  echo "$SECURE_SAN" | grep -q "DNS:secure.example.com" || { sleep 5; continue; }
  echo "$OTHER_SAN" | grep -q "DNS:other.example.com" || { sleep 5; continue; }
  [ "$SECURE_SAN" != "$OTHER_SAN" ] || { sleep 5; continue; }

  SECURE_ANS=$(curl -s --cacert /root/ca.crt --resolve "secure.example.com:443:$GWIP" "https://secure.example.com/hostname" 2>/dev/null)
  OTHER_ANS=$(curl -s --cacert /root/ca.crt --resolve "other.example.com:443:$GWIP" "https://other.example.com/hostname" 2>/dev/null)

  echo "$SECURE_ANS" | grep -q '^web-' && echo "$OTHER_ANS" | grep -q '^web-canary-' && exit 0
  sleep 5
done

exit 1

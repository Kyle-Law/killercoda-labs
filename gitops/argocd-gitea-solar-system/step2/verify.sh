#!/bin/bash

for i in $(seq 1 24); do
  RESP=$(curl -s -u admin:AdminPass123! http://localhost:30300/api/v1/repos/admin/solar-system 2>/dev/null)
  echo "$RESP" | grep -q '"empty":false' && exit 0
  sleep 5
done

exit 1

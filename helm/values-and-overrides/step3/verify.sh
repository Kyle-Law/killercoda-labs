#!/bin/bash

TARGET="You are overriding the message using a values file. You rock it!"

[ -f /charts/values.yaml ] || exit 1
grep -q "$TARGET" /charts/values.yaml || exit 1

for i in $(seq 1 12); do
  ACTUAL=$(helm get values mock-app -n dev-ns 2>/dev/null \
    | sed -n 's/^message:[[:space:]]*//p' \
    | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
  [ "$ACTUAL" == "$TARGET" ] && exit 0
  sleep 5
done

exit 1

#!/bin/bash

TARGET="You are overriding the message using an inline value. Good job!"

# Read the release's own values. The upstream version piped this through 'yq',
# which isn't guaranteed to be installed on the box - sed keeps it dependency-free.
for i in $(seq 1 12); do
  ACTUAL=$(helm get values mock-app -n dev-ns 2>/dev/null \
    | sed -n 's/^message:[[:space:]]*//p' \
    | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
  [ "$ACTUAL" == "$TARGET" ] && exit 0
  sleep 5
done

exit 1

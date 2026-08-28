#!/bin/bash

for i in $(seq 1 12); do
  helm -n team-yellow status devserver >/dev/null 2>&1 && exit 0
  sleep 5
done

exit 1

#!/bin/bash

# extracted chart must be present and be the pinned version
[ -f /root/charts/podinfo/Chart.yaml ] || exit 1

grep -qE '^version:[[:space:]]*6\.5\.4[[:space:]]*$' /root/charts/podinfo/Chart.yaml || exit 1
[ -d /root/charts/podinfo/templates ] || exit 1

exit 0

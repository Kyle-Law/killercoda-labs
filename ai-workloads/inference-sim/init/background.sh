#!/bin/bash

# Pre-pull the simulator image so the first step isn't waiting on a registry.
# It's small (~41MB compressed), but pulling it here keeps step 1 snappy.
ctr -n k8s.io images pull ghcr.io/llm-d/llm-d-inference-sim:v0.11.2 >/dev/null 2>&1 \
  || crictl pull ghcr.io/llm-d/llm-d-inference-sim:v0.11.2 >/dev/null 2>&1 \
  || true

touch /tmp/.initfinished

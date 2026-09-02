#!/bin/bash

[ -s /root/metrics.txt ] || exit 1

# must be a real Prometheus exposition from this simulator, carrying the
# vLLM-compatible metric names rather than, say, a saved JSON response
grep -q "^vllm:" /root/metrics.txt || exit 1
for m in vllm:num_requests_running vllm:prompt_tokens_total; do
  grep -q "$m" /root/metrics.txt || exit 1
done

# and the endpoint must still be live and scrapeable now
for i in $(seq 1 12); do
  curl -s --max-time 5 http://localhost:30800/metrics 2>/dev/null | grep -q "^vllm:" && exit 0
  sleep 5
done

exit 1

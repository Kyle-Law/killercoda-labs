# Network Signals Worth Alerting On

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Observability (15%) |
| **Exam objective** | Analyzing Network Health Using Metrics |
| **Proposed backend** | `kubernetes-kubeadm-2nodes` |
| **Feasibility** | Ready |

## What it teaches

Which network metrics indicate a real problem — drops, retransmits, DNS latency, endpoint churn, conntrack pressure — and which are noise that will page someone at 3am for nothing.

## Step outline

1. Scrape network metrics from the CNI and kube-proxy; establish a healthy baseline.
2. Induce a real fault and identify which signal moves first.
3. Distinguish a symptom metric from a cause metric.
4. Write one alert rule that would have caught the fault, and reason about its false-positive rate.

## Must resolve before building

- Which network metrics the backend's CNI actually exports.

## Cross-links

- Builds on `observability/prometheus-operator`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down.

# Rate Limiting Something That Has No Fixed Size

> **Status:** planned — not yet built. This file is the design spec, not a lab.

| | |
|---|---|
| **CKNE domain** | Advanced Traffic Management (20%) |
| **Exam objective** | Optimizing LLM Traffic |
| **Mapped tech** | Envoy AI Gateway |
| **Proposed backend** | `kubernetes-kubeadm-1node` |
| **Feasibility** | **Verify first** — a separate product from the Envoy Gateway already used here |

## What it teaches

The third lab on this sub-topic, and the one that covers the named product rather than the
mechanism. [`llm-routing`](../../llm-routing/) is plain Envoy Gateway and its limits;
[`inference-gateway`](../../inference-gateway/) is the Gateway API Inference Extension. Envoy AI
Gateway is the third thing the curriculum names and is neither of those.

What it adds over a general-purpose proxy: rate limiting denominated in **tokens** rather than
requests, a single API over backends that do not share one, and provider fallback.

## The finding at its heart

Every rate limiter you have used counts requests, because requests were roughly the same size.
One inference request can cost a hundred times another, so a request-per-minute limit either
starves small callers or fails to protect the backend at all. The unit has to change, and the
count is only known **after** the response — so the limiter is always spending budget it has
already committed.

## Step outline

1. **Show a request limit failing.** Rate limit by requests, then send one cheap and one very
   expensive request stream. Same quota consumed, wildly different cost — the limit is not
   protecting what it is supposed to protect.
2. **Limit on tokens instead.** Configure token-based rate limiting and watch the same two
   callers get treated according to what they actually consumed.
3. **The accounting problem.** Token counts arrive in the response, so the budget is debited
   after the fact. Find where that shows up — a caller can exceed its limit by exactly one
   large request, every time.
4. **Provider fallback.** Two backends behind one API, and what happens to an in-flight streamed
   response when the primary fails mid-stream — which is not the same as a failover on a request
   that had not started.

## Must resolve before building

- **Whether it installs on this backend at all**, and how heavily. It is a layer on Envoy
  Gateway with its own controller and CRDs. The `llm-routing` init already installs Envoy
  Gateway; confirm the two versions agree rather than fight over the Gateway API CRDs.
- **Whether `llm-d-inference-sim` reports token usage** in the response the limiter needs. It
  exports real vLLM metric names, so this is likely, but step 2 rests entirely on it.
- Whether step 4 needs a second, deliberately failing backend or can use the same simulator
  configured to fail.

## Cross-links

- Third in a sequence: [`llm-routing`](../../llm-routing/) →
  [`inference-gateway`](../../inference-gateway/) → this. Each should name the next.
- Reuses the simulator and the `llmload` open-loop generator from `llm-routing`.

---

Build to the repo's standard: `index.json`, `intro.md`, `init/`, `stepN/text.md` + `stepN/verify.sh`, `finish.md`.
Every claim in the text must be reproduced on a live cluster before it is written down, and every check must say
what it wanted — see the conventions in `ckne/README.md`.

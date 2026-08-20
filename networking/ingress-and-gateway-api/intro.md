
<br>

The current CKA curriculum lists both, side by side, under Services & Networking: **"know how to use Ingress controllers and Ingress resources"** and **"use the Gateway API to manage Ingress traffic."** Gateway API is the newer, more expressive successor — `GatewayClass`, `Gateway`, and `HTTPRoute` in place of a single `Ingress` object — but Ingress hasn't left the exam, and the two are expected to coexist for a while yet.

This lab installs `ingress-nginx` and routes real HTTP traffic through a classic `Ingress`, then models the identical routing intent with Gateway API objects. The second step verifies the **object graph** is wired correctly (`GatewayClass` → `Gateway` → `HTTPRoute` → Service) rather than live traffic — doing that for real needs a Gateway API-aware controller installed and configured, which is meaningfully more setup than this lab takes on.

> This is the most complex self-installed setup in this whole series — an ingress controller brings RBAC, an admission webhook, and a certificate-generation Job along with it, not just one Deployment. Treat step 1 as worth an extra close look if you hit anything unexpected.

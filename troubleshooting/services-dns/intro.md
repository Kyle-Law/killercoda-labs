
<br>

Services & Networking is 20% of the CKA exam, and "troubleshoot services and networking" is explicit exam content. Three failure classes, each with a different symptom:

1. A Service with no endpoints at all
2. A Service with endpoints, but connections still fail
3. Endpoints and connections both fine, but names won't resolve

Unlike most Pod fields, a **Service's spec is fully mutable** — no delete-and-recreate dance needed here, `kubectl apply` (or `edit`) on a corrected manifest is enough.

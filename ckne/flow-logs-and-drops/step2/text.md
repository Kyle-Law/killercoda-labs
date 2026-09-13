
Lock `api` down with a default-deny ingress policy, then use the flow log to answer a question you could not answer before: **not that traffic stopped, but why.**

Write the exact verdict string Hubble reports for the blocked flows to `/root/answers/step2.txt`.

<br>

<details><summary>Tip</summary>

A default-deny is a policy selecting `api`, naming `Ingress`, with no rules:

```plain
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-deny
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
EOF
sleep 10
apicall
```{{exec}}

Then look for what changed in the flow log:

```plain
flows --since 30s --to-pod api --verdict DROPPED
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-deny
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
EOF
sleep 10
apicall
```{{exec}}

> `GET /hostname -> 000`

`000` is curl's way of saying nothing answered at all. That is everything the client knows. No error message, no refusal — the packets simply vanished.

Now ask the network what it did:

```plain
flows --since 30s --to-pod api --verdict DROPPED
```{{exec}}

> ```
> default/scanner-...:38124 (ID:37223) <> default/api-...:8080 (ID:25203) policy-verdict:none TRAFFIC_DIRECTION_UNKNOWN DENIED (TCP Flags: SYN)
> default/scanner-...:38124 (ID:37223) <> default/api-...:8080 (ID:25203) Policy denied DROPPED (TCP Flags: SYN)
> ```

**`Policy denied DROPPED`** — and both ends named, on a `SYN`, so the connection never even opened.

```plain
echo "Policy denied DROPPED -- preceded by policy-verdict:none DENIED" > /root/answers/step2.txt
```{{exec}}

The pair of lines is worth reading carefully, because they say different things:

- **`policy-verdict:none ... DENIED`** — the *decision*. `none` means no policy rule matched this traffic. That is what default-deny means in practice: not "a rule rejected you", but "no rule permitted you".
- **`Policy denied DROPPED`** — the *action* that followed.

Notice it says `none` rather than naming a rule. **Allow-only APIs never tell you which rule blocked something, because no rule did.** The absence of a match is the block. Once you internalise that, "which policy is dropping my traffic?" becomes the wrong question — the right one is "which policy *should* have allowed it, and why doesn't it match?"

```plain
flows --since 60s --to-pod api --verdict FORWARDED | tail -3
```{{exec}}

> Nothing recent. Everything is being dropped, including `web`, which is a legitimate caller — a default-deny does not distinguish.

</details>

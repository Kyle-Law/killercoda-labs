
You know what talks to `api`, and which of those callers is legitimate. Write the policy that permits exactly that and nothing else, named `api-allow-web`.

Then prove it, using the flow log rather than trusting it: `web` still gets through, `scanner` is refused.

<br>

<details><summary>Tip</summary>

The observation from step 3 gives you every field the policy needs: the destination workload, the caller's labels, and the port the traffic actually arrives on.

```plain
flows --since 30s --to-pod api --from-pod web | head -2
```{{exec}}

Note the port on the **destination** side of the arrow — it is the container's port, not the Service's.

After applying, scope every check with `--since`. The buffer still holds flows from before the policy existed, and they will happily tell you the scanner is being forwarded.

</details>

<details><summary>Solution</summary>

```plain
flows --since 30s --to-pod api --from-pod web | head -2
```{{exec}}

> `... -> default/api-...:8080 ...` — port **8080**, the container port. The Service's port 80 never appears, because by the time the packet reaches the Pod the translation has already happened.

```plain
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-allow-web
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 8080
EOF
sleep 15
```{{exec}}

Now verify with the flow log, scoped to *after* the change:

```plain
echo "--- still getting through ---"
flows --since 20s --to-pod api --verdict FORWARDED | grep to-endpoint | awk '{print $4}' | cut -d: -f1 | sort -u
echo "--- now refused ---"
flows --since 20s --to-pod api --verdict DROPPED | awk '{print $4}' | cut -d: -f1 | sort -u
```{{exec}}

> ```
> --- still getting through ---
> default/web-79fbb8dd79-nh6wd
> --- now refused ---
> default/scanner-69574656d5-nttjd
> ```

Exactly one caller allowed, exactly the unauthorised one blocked — and you can *see* both facts rather than inferring them from a service that seems fine.

```plain
apicall
```{{exec}}

> `GET /hostname -> 000`

**Your own `cli` Pod is blocked too**, and that is correct: it is not `app=web`. A tight allow-list does not make an exception for the person who wrote it. If you want `cli` to keep working, it has to appear in the policy like any other caller — which is the point of writing allow-lists from observed traffic rather than from intention.

<br>

<details><summary>Info: why <code>--since</code> and not <code>--last</code></summary>

Try the same query the other way:

```plain
flows --last 200 --to-pod api --verdict FORWARDED | grep to-endpoint | awk '{print $4}' | cut -d: -f1 | sort -u
```{{exec}}

> `scanner` is probably still listed.

`--last N` returns N flows from the buffer regardless of age, and the buffer holds several minutes of history — including everything from before the policy existed. Used to check a change you just made, it will confirm the state you were trying to leave.

**Any "did my change work?" query against a flow log needs a time bound that starts after the change.** This is the same class of mistake as reading `iptables` counters without zeroing them first.

</details>

</details>

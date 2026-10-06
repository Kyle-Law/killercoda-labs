
Placing one Pod by hand is a Binding. A scheduler is that, in a loop.

`/root/web.yaml` is a Deployment with three replicas whose Pods all name `schedulerName: by-hand`. Nothing is running a scheduler by that name. **Write one**, in bash, with these rules and no others:

1. Find the Pods that name `by-hand` and have no node yet.
2. Pick the node that is running the fewest Pods.
3. Bind the Pod to it.
4. Do it again.

Leave it running in the background, then apply the Deployment. Every `web` Pod should end up `Running`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

You do not have to parse anything to find the unplaced Pods. Pods support field selectors on exactly the two things you need:

```plain
kubectl get pods -A --field-selector spec.schedulerName=by-hand,spec.nodeName=
```{{exec}}

An empty `spec.nodeName=` means *no node yet*. The same selector with a node's name counts what is already on that node:

```plain
kubectl get pods -A --field-selector spec.nodeName=$(cat /root/worker) --no-headers | wc -l
```{{exec}}

Bind with the request from the last step, with the namespace and name filled in. To keep the loop running while you carry on, start it with `nohup ... &`, or open a second terminal tab.

</details>

<details><summary>Solution</summary>

```plain
cat > /root/by-hand.sh <<'SCRIPT'
#!/bin/bash
# A scheduler with one scoring rule (fewest Pods) and no filters.
while true; do
  kubectl get pods -A --field-selector spec.schedulerName=by-hand,spec.nodeName= \
    -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name --no-headers 2>/dev/null |
  while read -r NS POD; do
    [ -n "$POD" ] || continue
    NODE=$(for N in $(kubectl get nodes -o name | cut -d/ -f2); do
             echo "$(kubectl get pods -A --field-selector spec.nodeName=$N --no-headers | wc -l) $N"
           done | sort -n | head -1 | awk '{print $2}')
    printf '{"apiVersion":"v1","kind":"Binding","metadata":{"name":"%s"},"target":{"apiVersion":"v1","kind":"Node","name":"%s"}}' "$POD" "$NODE" |
      kubectl create --raw "/api/v1/namespaces/$NS/pods/$POD/binding" -f - >/dev/null 2>&1 \
      && echo "bound $NS/$POD -> $NODE"
  done
  sleep 1
done
SCRIPT
chmod +x /root/by-hand.sh
nohup /root/by-hand.sh > /root/by-hand.log 2>&1 &
```{{exec}}

```plain
kubectl apply -f /root/web.yaml
sleep 10
kubectl get pods -l app=web -o wide
cat /root/by-hand.log
```{{exec}}

</details>

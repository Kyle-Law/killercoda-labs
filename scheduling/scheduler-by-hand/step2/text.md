
`batch-1` names a scheduler called `nightly-batch`, and nothing in this cluster is running one.

**Get `batch-1` running** — on any node, without deleting it, without recreating it, and without starting a scheduler of your own.

<br>

Then try the other thing the API will let you do. `/root/ghost.yaml` is another Pod waiting on `nightly-batch`. **Create it, and bind it to a node that does not exist**, named `nowhere`. See whether the API objects, and then keep an eye on the Pod.

When you have seen what becomes of it, write **one word** for it into `/root/answers/step2`.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

You cannot edit a Pod into having a node — `spec.nodeName` is not patchable on a Pod that exists. Placing one is a separate object, POSTed to a subresource of the Pod. It is exactly the request `kube-scheduler` makes.

```plain
kubectl explain binding
```{{exec}}

`kubectl create --raw` sends a request to a path you name, so it can reach a subresource that has no `kubectl` verb of its own:

```plain
kubectl create --raw /api/v1/namespaces/default/pods/<name>/binding -f -
```

The body is a `Binding` whose `target` is a `Node`.

</details>

<details><summary>Solution</summary>

```plain
NODE=$(cat /root/worker)
cat <<JSON | kubectl create --raw /api/v1/namespaces/default/pods/batch-1/binding -f -
{"apiVersion":"v1","kind":"Binding","metadata":{"name":"batch-1"},"target":{"apiVersion":"v1","kind":"Node","name":"$NODE"}}
JSON
```{{exec}}

```plain
kubectl get pod batch-1 -o wide
```{{exec}}

It runs. Now look at its events:

```plain
kubectl get events --field-selector involvedObject.name=batch-1
```{{exec}}

Pulling, Pulled, Created, Started — all written by the kubelet (`Pulling` and `Pulled` only if the image was not already on the node). There is no `Scheduled` event, because that one is written by the scheduler, and nothing here was.

Now the ghost:

```plain
kubectl apply -f /root/ghost.yaml
cat <<'JSON' | kubectl create --raw /api/v1/namespaces/default/pods/ghost/binding -f -
{"apiVersion":"v1","kind":"Binding","metadata":{"name":"ghost"},"target":{"apiVersion":"v1","kind":"Node","name":"nowhere"}}
JSON
```{{exec}}

The API accepts it. `Binding` checks nothing about the node:

```plain
kubectl get pod ghost -o wide
```{{exec}}

Now wait about a minute and ask again. The Pod is not `Failed` and not `Pending` — it is gone. The pod garbage collector deletes Pods that are bound to a node which does not exist, after a 40 second quarantine and on a 20 second cycle.

```plain
kubectl get pod ghost
echo deleted > /root/answers/step2
```{{exec}}

</details>

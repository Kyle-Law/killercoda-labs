
Step 3's fix was one file, on one machine, for one client. There are three namespaces here and there could be three hundred — every workload that ever talks to something signed by `lab-root-ca` needs that same certificate, in its own filesystem, in a format its own TLS library reads.

Copying it by hand is how trust stores go stale. `trust-manager` is installed, and its `Bundle` resource does this as a controller: read certificates from a source, write them into a ConfigMap in **every namespace matching a selector**, and keep them there.

Create a `Bundle` named `lab-ca-bundle` that:

- sources the CA certificate from the Secret holding it,
- targets a ConfigMap under the key `root-ca.pem`,
- goes **only** to namespaces labelled `trust=lab`.

Then label `app` and `client`, and bring up the consumer that mounts it:

```plain
kubectl apply -f /root/client.yaml
```{{exec}}

Prove it from inside the Pod — a namespace that has never seen the CA, on a machine that is not this one.

> **If CHECK does not pass**, run `why`{{exec}} — it prints the exact condition that was not met, and usually the command that shows you why.

<br>

<details><summary>Tip</summary>

```plain
kubectl explain bundle.spec.sources
```{{exec}}

A `Bundle` is cluster-scoped, so its sources come from `trust-manager`'s own trust namespace — which, like a `ClusterIssuer`'s, is where cert-manager is installed. The CA keypair you put there in step 2 is exactly the source you want, and you want its `tls.crt`.

Labelling a namespace:

```plain
kubectl label namespace app client trust=lab
```{{exec}}

And once the Pod is up:

```plain
kubectl -n client exec deploy/client -- ls /etc/trust
```{{exec}}

</details>

<details><summary>Solution</summary>

```plain
kubectl apply -f - <<'YAML'
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: lab-ca-bundle
spec:
  sources:
  - secret:
      name: root-ca-tls
      key: tls.crt
  target:
    configMap:
      key: root-ca.pem
    namespaceSelector:
      matchLabels:
        trust: lab
YAML
```{{exec}}

```plain
kubectl label namespace app client trust=lab
```{{exec}}

```plain
kubectl get bundle lab-ca-bundle
```{{exec}}

```plain
kubectl apply -f /root/client.yaml
kubectl -n client rollout status deploy/client
```{{exec}}

```plain
kubectl -n client exec deploy/client -- curl -sS --cacert /etc/trust/root-ca.pem https://web.app.svc.cluster.local:8443/
```{{exec}}

Then check where the ConfigMap did **not** go:

```plain
kubectl get configmap -A | grep lab-ca-bundle
```{{exec}}

Only the labelled namespaces. Trust distribution is opt-in by label, which means a new namespace joins by being labelled rather than by someone remembering to copy a file into it.

One last thing worth trying, because the refusal is the point:

```plain
kubectl apply -f - <<'YAML'
apiVersion: trust.cert-manager.io/v1alpha1
kind: Bundle
metadata:
  name: key-leak-test
spec:
  sources:
  - secret:
      name: root-ca-tls
      key: tls.key
  target:
    configMap:
      key: leak.pem
    namespaceSelector:
      matchLabels:
        trust: lab
YAML
```{{exec}}

```plain
kubectl get bundle key-leak-test -o jsonpath='{.status.conditions[0].message}'
```{{exec}}

```plain
kubectl delete bundle key-leak-test
```{{exec}}

</details>
